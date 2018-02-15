#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <fcntl.h>
#include "common.h"

struct __attribute__((__packed__)) JAILBREAKD_PACKET {
    uint8_t Command;
    int32_t Pid;
};

int jailbreakd_sockfd = -1;
pid_t jailbreakd_pid = 0;

void openjailbreakdsocket() {
    const char *hostname = "127.0.0.1";
    int portno = 5;
    
    struct sockaddr_in serveraddr;
    memset(&serveraddr, 0, sizeof(serveraddr));
    serveraddr.sin_family = AF_INET;
    
    inet_pton(AF_INET, hostname, &serveraddr.sin_addr);
    
    serveraddr.sin_port = htons(portno);
    
    // Open stream socket
    int sock;
    if ((sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0) {
        fprintf(stderr, "Error: could not create socket. \n");
        return;
    }
    
    int flag = 1;
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, (char *) &flag, sizeof(int));
    
    int set = 1;
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(int));
    
    if (connect(sock, (struct sockaddr*)&serveraddr, sizeof(serveraddr)) < 0) {
        fprintf(stderr, "could not connect to server\n");
        close(sock);
    }
    jailbreakd_sockfd = sock;
    
    int fd = open("/var/tmp/jailbreakd.pid", O_RDONLY, 0600);
    if (fd < 0) {
        fprintf(stderr, "WHAT! \n");
        return;
    }
    char pid[8] = {0};
    read(fd, pid, 8);
    jailbreakd_pid = atoi(pid);
    close(fd);
}

void calljailbreakd(pid_t pid, uint8_t command) {
    if (jailbreakd_sockfd == -1) {
        openjailbreakdsocket();
    }
    
    int fd = open("/var/tmp/jailbreakd.pid", O_RDONLY, 0600);
    if (fd < 0) {
        fprintf(stderr, "WHAT! \n");
        return;
    }
    
    char jbd_pid_buf[8] = {0};
    read(fd, jbd_pid_buf, 8);
    pid_t jbd_pid = atoi(jbd_pid_buf);
    close(fd);
    
    if (jbd_pid != jailbreakd_pid) {
        fprintf(stderr, "jailbreakd restart detected... forcing reconnect\n");
        closejailbreakfd();
        openjailbreakdsocket();
    }
    
    if (jailbreakd_sockfd == -1) {
        fprintf(stderr, "server not connected. giving up...\n");
        return;
    }
    
    char buf[1024];
    
    /* get a message from the user */
    bzero(buf, 1024);
    
    struct JAILBREAKD_PACKET entitlePacket;
    entitlePacket.Command = command;
    entitlePacket.Pid = pid;
    
    memcpy(buf, &entitlePacket, sizeof(entitlePacket));
    
    int bytesSent = send(jailbreakd_sockfd, buf, sizeof(struct JAILBREAKD_PACKET), 0);
    if (bytesSent < 0) {
        fprintf(stderr, "Server probably disconnected. Trying again... \n");
        
        closejailbreakfd();
        openjailbreakdsocket();
        
        if (jailbreakd_sockfd == -1){
            fprintf(stderr, "Server not connected. Giving up... \n");
            return;
        }
        
        bytesSent = send(jailbreakd_sockfd, buf, sizeof(struct JAILBREAKD_PACKET), 0);
        if (bytesSent < 0) {
            fprintf(stderr, "Server probably disconnected again. Giving up... \n");
        }
    }
}

void closejailbreakfd(void) {
    close(jailbreakd_sockfd);
    jailbreakd_sockfd = -1;
}
