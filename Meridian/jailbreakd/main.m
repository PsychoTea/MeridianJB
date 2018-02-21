#import <Foundation/Foundation.h>
#include <stdio.h>
#include <mach/mach.h>
#include <mach/error.h>
#include <mach/message.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <pthread.h>
#include "patchfinder64.h"
#include "kern_utils.h"
#include "kmem.h"
#include "kexecute.h"

#define PROC_PIDPATHINFO_MAXSIZE  (4 * MAXPATHLEN)
int proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize);

#define JAILBREAKD_CLOSE_CONNECTION 0

#define JAILBREAKD_COMMAND_ENTITLE 1
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT 2
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY 3
#define JAILBREAKD_COMMAND_FIXUP_SETUID 4

// Generic TCP packet
// all jbd packets match this format
struct __attribute__((__packed__)) JAILBREAKD_PACKET {
    uint8_t Command;
    int32_t Pid;
    uint8_t Wait;
};

// resposne packet
// sent after request to notify it has been completed
struct __attribute__((__packed__)) RESPONSE_PACKET {
    uint8_t Response;
};

mach_port_t tfpzero;
uint64_t kernel_base;
uint64_t kernel_slide;

#define MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT 6
int memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);

int remove_memory_limit(void) {
    return memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT, getpid(), 0, NULL, 0);
}

int is_valid_command(uint8_t command) {
    return (command == JAILBREAKD_COMMAND_ENTITLE ||
            command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT ||
            command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY ||
            command == JAILBREAKD_COMMAND_FIXUP_SETUID);
}

struct InitThreadArg {
    int clientFd;
};

int threadCount = 0;

void *initThread(struct InitThreadArg *args) {
    int yes = 1;
    setsockopt(args->clientFd, SOL_SOCKET, SO_KEEPALIVE, &yes, sizeof(int));
    
    int alive = 1;
    setsockopt(args->clientFd, IPPROTO_TCP, TCP_KEEPALIVE, &alive, sizeof(int));
    
    int set = 1;
    setsockopt(args->clientFd, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
    
    int shouldClose = 0;
    
    char buf[1024];
    
    while (true) {
        bzero(buf, 1024);
        int bytesRead = recv(args->clientFd, buf, 1024, 0);
        
        if (!bytesRead) continue;
        
        int bytesProcessed = 0;
        while (bytesProcessed < bytesRead) {
            if (bytesRead - bytesProcessed >= sizeof(struct JAILBREAKD_PACKET)) {
                struct JAILBREAKD_PACKET *packet = (struct JAILBREAKD_PACKET *)(buf + bytesProcessed);
                
                if (!is_valid_command(packet->Command)) {
                    NSLog(@"Invalid command recieved.");
                }
                
                char *name = proc_name(packet->Pid);
                
                if (packet->Command == JAILBREAKD_CLOSE_CONNECTION) {
                    NSLog(@"JAILBREAKD_CLOSE_CONNECTION PID: %d NAME: %s", packet->Pid, name);
                    shouldClose = 1;
                }
                
                if (packet->Command == JAILBREAKD_COMMAND_ENTITLE) {
                    NSLog(@"JAILBREAKD_COMMAND_ENTITLE PID: %d NAME: %s", packet->Pid, name);
                    setcsflagsandplatformize(packet->Pid);
                }
                
                if (packet->Command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT) {
                    NSLog(@"JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT PID: %d NAME: %s", packet->Pid, name);
                    setcsflagsandplatformize(packet->Pid);
                    kill(packet->Pid, SIGCONT);
                }
                
                if (packet->Command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY) {
                    NSLog(@"JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY PID: %d NAME: %s", packet->Pid, name);
                    __block int PID = packet->Pid;
                    
                    dispatch_queue_t queue = dispatch_queue_create("org.coolstar.jailbreakd.delayqueue", NULL);
                    dispatch_async(queue, ^{
                        char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
                        bzero(pathbuf, sizeof(pathbuf));
                        
                        int ret = proc_pidpath(PID, pathbuf, sizeof(pathbuf));
                        while (ret > 0 && strcmp(pathbuf, "/usr/libexec/xpcproxy") == 0){
                            proc_pidpath(PID, pathbuf, sizeof(pathbuf));
                            usleep(100);
                        }
                        
                        ret = setcsflagsandplatformize(PID);
                        if (ret == 0) {
                            kill(PID, SIGCONT);
                        }
                    });
                    dispatch_release(queue);
                }
                
                if (packet->Command == JAILBREAKD_COMMAND_FIXUP_SETUID) {
                    NSLog(@"JAILBREAKD_FIXUP_SETUID PID: %d NAME: %s", packet->Pid, name);
                    fixupsetuid(packet->Pid);
                }
                
//                if (packet->Wait == 1) {
//                    bzero(buf, 1024);
//
//                    struct RESPONSE_PACKET responsePacket;
//                    responsePacket.Response = 0;
//                    memcpy(buf, &responsePacket, sizeof(responsePacket));
//
//                    int sent = send(args->clientFd, buf, sizeof(struct RESPONSE_PACKET), 0);
//                    if (sent < 0) {
//                        NSLog(@"Failed to send wait message, trying again...");
//                        sent = send(args->clientFd, buf, sizeof(struct RESPONSE_PACKET), 0);
//                    }
//                }
                
                free(name);
            }
            
            bytesProcessed += sizeof(struct JAILBREAKD_PACKET);
        }
    }
    
    if (shouldClose == 1) {
        close(args->clientFd);
    }
    
    threadCount--;
    
    return NULL;
}

int launch_server() {
    struct sockaddr_in serveraddr;
    struct sockaddr_in clientaddr;
    
    NSLog(@"Running server...");
    int listenFd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (listenFd < 0) {
        NSLog(@"Error opening socket. Ret val: %d", listenFd);
    }
    
    int optval = 1;
    setsockopt(listenFd, SOL_SOCKET, SO_REUSEADDR, (const void *)&optval, sizeof(int));
    
    struct hostent *server;
    char *hostname = "127.0.0.1";
    server = gethostbyname(hostname);
    if (server == NULL) {
        NSLog(@"ERROR, no such host as %s", hostname);
        exit(0);
    }
    
    bzero((char *) &serveraddr, sizeof(serveraddr));
    serveraddr.sin_family = AF_INET;
    bcopy((char *)server->h_addr, (char *)&serveraddr.sin_addr.s_addr, server->h_length);
    serveraddr.sin_port = htons((unsigned short)5);
    
    if (bind(listenFd, (struct sockaddr *)&serveraddr, sizeof(serveraddr)) < 0){
        NSLog(@"Error binding...");
        term_kernel();
        exit(-1);
    }
    
    NSLog(@"Successfully bound on socket %d", listenFd);
    
    listen(listenFd, 5);
    
    NSLog(@"Server running!");
    
    socklen_t clientlen = sizeof(clientaddr);
    
    while (true) {
        int clientFd = accept(listenFd, (struct sockaddr *)&clientaddr, &clientlen);
        
        if (clientFd < 0) {
            NSLog(@"Unable to accept.");
            continue;
        }
        
        struct InitThreadArg args;
        args.clientFd = clientFd;
        
        pthread_t thread;
        int err = pthread_create(&thread, NULL, (void *(*)(void *))&initThread, &args);
        if (err != 0) {
            NSLog(@"Unable to create thread.");
            pthread_detach(thread);
        }
        
        threadCount++;
    }
    
    _exit(0);
    return 0;
}

int main(int argc, char **argv, char **envp) {
    NSLog(@"[jailbreakd] Start");
    
    // Write pid file so Meridian.app knows we're running
    unlink("/var/tmp/jailbreakd.pid");
    FILE *f = fopen("/var/tmp/jailbreakd.pid", "w");
    fprintf(f, "%d\n", getpid());
    fclose(f);
    
    kernel_base = strtoull(getenv("KernelBase"), NULL, 16);
    kernprocaddr = strtoull(getenv("KernProcAddr"), NULL, 16);
    offset_zonemap = strtoull(getenv("ZoneMapOffset"), NULL, 16);
    
    remove_memory_limit();
    
    kern_return_t err = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, &tfpzero);
    if (err != KERN_SUCCESS) {
        NSLog(@"host_get_special_port 4: %s", mach_error_string(err));
        return -1;
    }
    
    init_kernel(kernel_base, NULL);
    kernel_slide = kernel_base - 0xFFFFFFF007004000;
    NSLog(@"[jailbreakd] tfp: 0x%016llx", (uint64_t)tfpzero);
    NSLog(@"[jailbreakd] slide: 0x%016llx", kernel_slide);
    NSLog(@"[jailbreakd] kernproc: 0x%016llx", kernprocaddr);
    NSLog(@"[jailbreakd] zonemap: 0x%016llx", offset_zonemap);
    
    int ret = launch_server();
    exit(ret);
}
