FROM ubuntu:22.04 as base
# FROM jrei/systemd-ubuntu:22.04

ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive


RUN apt update && \
    apt install -y sudo curl git net-tools python3 file netcat socat conntrack ipset iproute2 vim kmod dnsutils cgroupfs-mount systemd iputils-ping

ENTRYPOINT [ "systemd" ]

# RUN git clone https://github.com/gdraheim/docker-systemctl-replacement.git /root/docker-systemctl-replacement && \
#     ln -s /root/docker-systemctl-replacement/files/docker/systemctl3.py /usr/bin/systemctl && \
#     ln -s /root/docker-systemctl-replacement/files/docker/journalctl3.py /usr/bin/journalctl && \
#     touch /var/log/systemctl.log

# CMD /usr/bin/systemctl --init --verbose
