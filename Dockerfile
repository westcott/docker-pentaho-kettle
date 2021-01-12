FROM ubuntu:18.04

# install necessary dependencies
RUN  sed 's/main$/main universe/' -i /etc/apt/sources.list && \
	apt update && apt-get install -y software-properties-common unzip git lftp sudo zip curl wget && \
	apt-get clean && apt-get update -y && \
	apt-get install -y locales && \
	locale-gen en_US.UTF-8 && \
	sudo apt-get install -y libwebkitgtk-1.0.0 && \
	sudo apt install -y openjdk-8-jdk && \
	apt-get clean && \
	# remove the lists fetched by apt-get-update
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /var/cache/oracle-jdk8-installer && \
	echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
	rm -rf /tmp/*

# Set the locale
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8 
RUN update-locale LANG=en_US.UTF-8 LC_MESSAGES=POSIX

# this workaround is obsolete
# Fix certificate issues, found as of 
# https://bugs.launchpad.net/ubuntu/+source/ca-certificates-java/+bug/983302/comments/8
# should not be needed anymore so commenting the next five lines out
# RUN apt-get install -y ca-certificates-java && \
# 	apt-get clean && \
# 	update-ca-certificates -f && \
# 	rm -rf /var/lib/apt/lists/* && \
# 	rm -rf /var/cache/oracle-jdk8-installer;

# Making the right java available
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

# Configs directories and users for pentaho 
RUN mkdir /pentaho && \
  mkdir /home/pentaho && \
  mkdir /home/pentaho/.kettle && \
  mkdir /home/pentaho/.aws && \
  groupadd -r pentaho && \
  useradd -r -g pentaho -p $(perl -e'print crypt("pentaho", "aa")' ) -G sudo pentaho && \ 
  chown -R pentaho.pentaho /pentaho && \ 
  chown -R pentaho.pentaho /home/pentaho


WORKDIR /pentaho
USER pentaho

# currently using this version
# ARG PENTAHO_DOWNLOAD_URL=https://iweb.dl.sourceforge.net/project/pentaho/Pentaho%209.1/client-tools/pdi-ce-9.1.0.0-324.zip

##########################################################################################
# Downloads pentaho --instead, manually unzipped into /bi-data-engine/containers/kettle/ #
# unzip would take forever on deploy
##########################################################################################
COPY --chown=pentaho:pentaho pentaho /pentaho

# RUN wget -q -O kettle.zip ${PENTAHO_DOWNLOAD_URL} && \
#   unzip -qq kettle.zip && \
#   rm -rf kettle.zip

WORKDIR /

# copy the rest of the content
COPY scripts /scripts
COPY test /test

WORKDIR /pentaho/data-integration

# Adds connections config files
ADD --chown=pentaho:pentaho scripts/* ./
ADD --chown=pentaho:pentaho test/* ./

# Changes spoon.sh to expose memory to env-vars
RUN sudo sed -i \
  's/-Xmx[0-9]\+m/-Xmx\$\{_RUN_XMX:-2048\}m/g' spoon.sh 

ENV PDI_HOME /pentaho/data-integration

RUN sudo apt-get update && \
    sudo apt-get install -y \
        python3-pip \
        python3-setuptools \
        groff \
        less \
    && pip3 install --upgrade pip \
    && sudo apt-get clean

RUN sudo python3 -m pip --no-cache-dir install --upgrade awscli 

ENTRYPOINT ["/pentaho/data-integration/run.sh"]

# EXPOSE 9191