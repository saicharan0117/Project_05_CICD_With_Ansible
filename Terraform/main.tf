
provider "aws" { 
  profile = "default"
  region  = "us-east-1"
}

# Creating a New Key
resource "aws_key_pair" "Key-Pair" {

  # Name of the Key
  key_name = "MyKey"

  # Adding the SSH authorized key !
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCrCCCltkvebReWfi/ON98yZLyMeuZrKpMZF+tJGdfGYz8BSX00DLtYATUT5OqE++8Dpf8qInxJQ1s4LAN7mCkiiJMTL+gaHZB54SX1vAZGzZxz+x0UawponRTsNXTyooTz3B3H8KAsLAcgg+NU7IwrEKIQKDGGkT0K//654DoUyXOWU1s2JfiCh9bskHH1eOqMdz4RNNEJVxsNMg8+gUftfajipo8+WyCd0uVEoS66Laiag6LjNgKB8W0tG7CNr0yhB3zqX2uaBdHfjXNbs7ajK8A1kL+nK2MDdueSIDMvhyKg+1BLc90NJYXOS7vm6QKdMsXI56XeJsGk3e7ZEhmNAJMj1elS503a//1aH21ZxxMXwN0o5WOELrAOk/QhHgxCRISbFC0lKi45LNpJcb2WbD2gZ/QHOpcYDW5Qgjdo9a8ohMzdfA6eq4LYtEA8S0hNHEkqP24DgJgoQErcXXzMXv8DnPPPeHmiM+7UPmR04QPmyohJmUvw0d6gZ7CjbPE8LYoXeRQDP6zY5dlT4If8VFLp7avlxqkJPURFmDJ/s4BeU6wfZn+5aDtjsWopC2mpBwdHeGppNlQOv1D9QDM6y4NNC0lQTZNaPGPphcTPjAVgfGv44eNOGyNvMDLsycul2Pe0IfTb0yx1+lgYwEz3u5JSuu7zz/XNKfQllFRV3w== saicharankatukam@Sais-MacBook-Air.local"

}


# Creating a VPC!
resource "aws_vpc" "prod" {

  # IP Range for the VPC
  cidr_block = "172.20.0.0/16"

  # Enabling automatic hostname assigning
  enable_dns_hostnames = true
  tags = {
    Name = "prod"
  }
}


# Creating Public subnet!
resource "aws_subnet" "subnet1" {
  depends_on = [
    aws_vpc.prod
  ]

  # VPC in which subnet has to be created!
  vpc_id = aws_vpc.prod.id

  # IP Range of this subnet
  cidr_block = "172.20.10.0/24"

  # Data Center of this subnet.
  availability_zone = "us-east-1a"

  # Enabling automatic public IP assignment on instance launch!
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet"
  }
}



# Creating an Internet Gateway for the VPC
resource "aws_internet_gateway" "Internet_Gateway" {
  depends_on = [
    aws_vpc.prod,
    aws_subnet.subnet1,
  ]

  # VPC in which it has to be created!
  vpc_id = aws_vpc.prod.id

  tags = {
    Name = "IG-Public-&-Private-VPC"
  }
}

# Creating an Route Table for the public subnet!
resource "aws_route_table" "Public-Subnet-RT" {
  depends_on = [
    aws_vpc.prod,
    aws_internet_gateway.Internet_Gateway
  ]

  # VPC ID
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Internet_Gateway.id
  }

  tags = {
    Name = "Route Table for Internet Gateway"
  }
}

# Creating a resource for the Route Table Association!
resource "aws_route_table_association" "RT-IG-Association" {

  depends_on = [
    aws_vpc.prod,
    aws_subnet.subnet1,
    aws_route_table.Public-Subnet-RT
  ]

  # Public Subnet ID
  subnet_id = aws_subnet.subnet1.id

  #  Route Table ID
  route_table_id = aws_route_table.Public-Subnet-RT.id
}

# Creating a Security Group for Jenkins
resource "aws_security_group" "JENKINS-SG" {

  depends_on = [
    aws_vpc.prod,
    aws_subnet.subnet1,
  ]

  description = "HTTP, PING, SSH"

  # Name of the security Group!
  name = "jenkins-sg"

  # VPC ID in which Security group has to be created!
  vpc_id = aws_vpc.prod.id

  # Created an inbound rule for webserver access!
  ingress {
    description = "HTTP for webserver"
    from_port   = 80
    to_port     = 8080

    # Here adding tcp instead of http, because http in part of tcp only!
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Created an inbound rule for ping
  ingress {
    description = "Ping"
    from_port   = 0
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Created an inbound rule for SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22

    # Here adding tcp instead of ssh, because ssh in part of tcp only!
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outward Network Traffic for the WordPress
  egress {
    description = "output from webserver"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating security group for MyApp, this will allow access only from the instances having the security group created above.
resource "aws_security_group" "MYAPP-SG" {

  depends_on = [
    aws_vpc.prod,
    aws_subnet.subnet1,
    ]

  description = "MyApp Access only from the Webserver Instances!"
  name        = "myapp-sg"
  vpc_id      = aws_vpc.prod.id

  # Created an inbound rule for MyApp
  ingress {
    description     = "MyApp Access"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  #  security_groups = [aws_security_group.JENKINS-SG.id]
  }

  # Created an inbound rule for SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22

    # Here adding tcp instead of ssh, because ssh in part of tcp only!
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "output from MyApp"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating an AWS instance for the Jenkins!
resource "aws_instance" "jenkins" {

  depends_on = [
    aws_vpc.prod,
    aws_subnet.subnet1,
    aws_security_group.JENKINS-SG
  ]

  ami           = "ami-0341d95f75f311023" 
  # amazoon-linux
  instance_type = "t2.large"
  subnet_id     = aws_subnet.subnet1.id

  # Keyname and security group are obtained from the reference of their instances created above!
  # Here I am providing the name of the key which is already uploaded on the AWS console.
  key_name = "MyKey"

  # Security groups to use!
  vpc_security_group_ids = [aws_security_group.JENKINS-SG.id]

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install wget ",
      "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
      "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key",	    
      "sudo yum upgrade -y",
      "sudo dnf install java-17-amazon-corretto -y",	  
      "sudo yum install jenkins -y",
 	    "sudo systemctl start jenkins",
      "sudo systemctl enable jenkins",
	    "sudo yum install git maven -y",
      "sudo yum install ansible -y",
      "sudo yum install docker -y",
      "sudo service docker start",
      "sudo usermod -aG docker $USER",
      "sudo usermod -aG docker jenkins",
      "sudo systemctl enable docker.service",
      "sudo systemctl enable containerd.service",
      "systemctl restart docker",
	    "sudo chmod 666 /var/run/docker.sock",
      "systemctl restart docker",
      "sudo docker run -itd --name sonar -p 9000:9000 sonarqube",
      "sudo rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.18.3/trivy_0.18.3_Linux-64bit.rpm",
    ]
  }
  tags = {
    Name = "Jenkins_From_Terraform"
  }

}

# Creating an AWS instance for the MyApp! It should be launched in the private subnet!
resource "aws_instance" "MyApp" {
  depends_on = [
    aws_instance.jenkins,
  ]

  # i.e. MyApp Installed!
  ami           = "ami-0341d95f75f311023"  # amazoon-linux
  instance_type = "t2.large"
  subnet_id     = aws_subnet.subnet1.id

  # Keyname and security group are obtained from the reference of their instances created above!
  key_name = "MyKey"


  # Attaching 2 security groups here, 1 for the MyApp Database access by the Web-servers,
  vpc_security_group_ids = [aws_security_group.MYAPP-SG.id]

  tags = {
    Name = "MyApp_From_Terraform"
  }
}
