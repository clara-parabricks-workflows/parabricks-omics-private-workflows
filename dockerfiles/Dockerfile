FROM ubuntu:latest 

# Update Linux package repos 
RUN apt update -y

# Install Linux packages 
RUN apt install -y python3-pip curl jq unzip

# Install Python packages
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

# Install AWS CLI 
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install