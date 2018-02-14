#import <Foundation/Foundation.h>
#include <stdio.h>
#include <mach/mach.h>
#include <mach/error.h>
#include <mach/message.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <unistd.h>

int jailbreakd_sockfd = -1;
struct sockaddr_in jailbreakd_serveraddr;
int jailbreakd_serverlen;
struct hostent *jailbreakd_server;

#define JAILBREAKD_COMMAND_ENTITLE 1
#define JAILBREAKD_COMMAND_FIXUP_SETUID 8

struct __attribute__((__packed__)) JAILBREAKD_ENTITLE_PID {
    uint8_t Command;
    int32_t Pid;
};

struct __attribute__((__packed__)) JAILBREAKD_FIXUP_SETUID {
    uint8_t Command;
    int32_t Pid;
};

void openjailbreakdsocket() {
    char *hostname = "127.0.0.1";
    int portno = 5;
    
    jailbreakd_sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (jailbreakd_sockfd < 0)
        printf("ERROR opening socket\n");
    
    /* gethostbyname: get the server's DNS entry */
    jailbreakd_server = gethostbyname(hostname);
    if (jailbreakd_server == NULL) {
        fprintf(stderr,"ERROR, no such host as %s\n", hostname);
        exit(0);
    }
    
    /* build the server's Internet address */
    bzero((char *) &jailbreakd_serveraddr, sizeof(jailbreakd_serveraddr));
    jailbreakd_serveraddr.sin_family = AF_INET;
    bcopy((char *)jailbreakd_server->h_addr,
          (char *)&jailbreakd_serveraddr.sin_addr.s_addr, jailbreakd_server->h_length);
    jailbreakd_serveraddr.sin_port = htons(portno);
    
    jailbreakd_serverlen = sizeof(jailbreakd_serveraddr);
}

void closejailbreakfd(void) {
    close(jailbreakd_sockfd);
    jailbreakd_sockfd = -1;
}

void calljailbreakd(pid_t pid, uint8_t command) {
    if (jailbreakd_sockfd == -1) {
        openjailbreakdsocket();
    }
    
    char buf[1024];
    bzero(buf, sizeof(buf));
    
    if (command == JAILBREAKD_COMMAND_ENTITLE) {
        struct JAILBREAKD_ENTITLE_PID entitlePacket;
        entitlePacket.Command = command;
        entitlePacket.Pid = pid;
        
        memcpy(buf, &entitlePacket, sizeof(entitlePacket));
    } else if (command == JAILBREAKD_COMMAND_FIXUP_SETUID) {
        struct JAILBREAKD_FIXUP_SETUID entitlePacket;
        entitlePacket.Command = command;
        entitlePacket.Pid = pid;
        
        memcpy(buf, &entitlePacket, sizeof(entitlePacket));
    } else {
        NSLog(@"Unknown jailbreakd command: %d", command);
        return;
    }
    
    int rv = sendto(jailbreakd_sockfd, buf, sizeof(entitlePacket), 0, (const struct sockaddr *)&jailbreakd_serveraddr, jailbreakd_serverlen);
    if (rv < 0) {
        NSLog(@"Error in sendto: %d", rv);
    }
}

void jb_oneshot_entitle_now(pid_t pid) {
    openjailbreakdsocket();
    
    calljailbreakd(pid, JAILBREAKD_COMMAND_ENTITLE);
    
    closejailbreakfd();
}

void jb_oneshot_fix_setuid_now(pid_t pid) {
    openjailbreakdsocket();
    
    calljailbreakd(pid, JAILBREAKD_COMMAND_FIXUP_SETUID);
    
    closejailbreakfd();
}
