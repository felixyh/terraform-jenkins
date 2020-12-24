provider "aws" {
  region                  = "us-east-2"
  shared_credentials_file = "/Users/felix/.aws/credentials"
  profile                 = "cncore"
}


############################
# Lab Guide Tasks #
############################
# 1. Create vpc

resource "aws_vpc" "my-lab-vpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "My Lab VPC"
  }
}


# 2. Create Internet Gateway, nat gateway, network interface, eip

resource "aws_internet_gateway" "prod-gw" {
  vpc_id = aws_vpc.my-lab-vpc.id

  tags = {
    Name = "prod-gw"
  }
}


resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public-subnet-1.id
  depends_on = [aws_internet_gateway.prod-gw]
  tags = {
    Name = "gw NAT"
  }
}


resource "aws_eip" "nat" {
  vpc                       = true
}


# 3. Create Custom route table

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.my-lab-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }


  tags = {
    Name = "public-routetable"
  }
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.my-lab-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }


  tags = {
    Name = "private-routetable"
  }
}

# 4. Create a subnet
resource "aws_subnet" "public-subnet-1" {
  vpc_id     = aws_vpc.my-lab-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "Public Subnet 1"
  }
}


resource "aws_subnet" "private-subnet-1" {
  vpc_id     = aws_vpc.my-lab-vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "Private Subnet 1"
  }
}


resource "aws_subnet" "public-subnet-2" {
  vpc_id     = aws_vpc.my-lab-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "Public Subnet 2"
  }
}


resource "aws_subnet" "private-subnet-2" {
  vpc_id     = aws_vpc.my-lab-vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "Private Subnet 2"
  }
}

# 5. Associate subnet with Route table

resource "aws_route_table_association" "public-association-1" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_route_table_association" "public-association-2" {
  subnet_id      = aws_subnet.public-subnet-2.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_route_table_association" "private-association-1" {
  subnet_id      = aws_subnet.private-subnet-1.id
  route_table_id = aws_route_table.private-route-table.id
}

resource "aws_route_table_association" "private-association-2" {
  subnet_id      = aws_subnet.private-subnet-2.id
  route_table_id = aws_route_table.private-route-table.id
}

# 6. Create security group to allow port 22, 80, 443

resource "aws_security_group" "cncorelab-sg" {
  name        = "cncorelab-sg"
  description = "Allow inbound traffic from limited ports and SrcIP"
  vpc_id      = aws_vpc.my-lab-vpc.id

    # Allow ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["218.2.208.75/32", "18.162.103.100/32", "36.152.113.203/32", "58.212.197.96/32", aws_vpc.my-lab-vpc.cidr_block]
  }

    # Allow RDP
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["218.2.208.75/32", "18.162.103.100/32", "36.152.113.203/32", "58.212.197.96/32", aws_vpc.my-lab-vpc.cidr_block]
  }

    # Allow TLS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["218.2.208.75/32", "18.162.103.100/32", "36.152.113.203/32", "58.212.197.96/32", aws_vpc.my-lab-vpc.cidr_block]
  }

    # Allow http
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["218.2.208.75/32", "18.162.103.100/32", "36.152.113.203/32", "58.212.197.96/32", aws_vpc.my-lab-vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cncorelab-sg"
  }
}

# 7. Create a network interface with an IP in the subnet that was create in step 4



# 8. Assign an elastic IP to the network interface created in step 7


# 9. Create Ubuntu server and install/enable apache2


resource "aws_instance" "webserver1" {
  ami = "ami-09558250a3419e7d0"
  instance_type = "t2.micro"
  key_name = "AWS_Key_Felix"
  subnet_id = aws_subnet.public-subnet-2.id
  vpc_security_group_ids = [aws_security_group.cncorelab-sg.id]
  associate_public_ip_address = true

  # network_interface {
  #   device_index = 0
  #   network_interface_id = aws_network_interface.web-server-nic.id
  # }

  user_data = <<-EOF
              #!/bin/bash -ex 
              yum -y install httpd php mysql php-mysql 
              chkconfig httpd on 
              service httpd start 
              if [ ! -f /var/www/html/lab-app.tgz ]; then 
              cd /var/www/html 
              wget https://us-west-2-tcprod.s3.amazonaws.com/courses/ILT-TF-100-TECESS/v4.5.2/lab-1-build-a-web-server/scripts/lab-app.tgz 
              tar xvfz lab-app.tgz
              chown apache:root /var/www/html/rds.conf.php 
              fi
              EOF


  tags = {
    Name = "Felix-webserver-emailtest"
  }
}


# resource "aws_instance" "webserver2" {
#   ami = "ami-09558250a3419e7d0"
#   instance_type = "t3.micro"
#   key_name = "AWS_Key_Felix"
#   vpc_security_group_ids = [aws_security_group.cncorelab-sg.id]
#   subnet_id = aws_subnet.prod-subnet-2.id
#   associate_public_ip_address = true
#   # network_interface {
#   #   device_index = 0
#   #   network_interface_id = aws_network_interface.web2-server-nic.id
#   # }

#   user_data = <<-EOF
#               #!/bin/bash -ex 
#               yum -y install httpd php mysql php-mysql 
#               chkconfig httpd on 
#               service httpd start 
#               if [ ! -f /var/www/html/lab-app.tgz ]; then 
#               cd /var/www/html 
#               wget https://us-west-2-tcprod.s3.amazonaws.com/courses/ILT-TF-100-TECESS/v4.5.2/lab-1-build-a-web-server/scripts/lab-app.tgz 
#               tar xvfz lab-app.tgz
#               chown apache:root /var/www/html/rds.conf.php 
#               fi
#               EOF


#   tags = {
#     Name = "Felix-webserver-2"
#   }
# }


# # 11. Create ELB

# resource "aws_lb" "http_elb" {
#   name               = "http-elb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.cncorelab-sg.id]
#   subnets            = [aws_subnet.prod-subnet-1.id, aws_subnet.prod-subnet-2.id]
#    tags = {
#     Name = "http-elb"
#   }
#   }
  
# resource "aws_lb_target_group" "target-grp" {
#   name     = "target-grp"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.prod-vpc.id
#   health_check {
#                 path = "/"
#                 port = "80"
#                 protocol = "HTTP"
#                 healthy_threshold = 2
#                 unhealthy_threshold = 2
#                 interval = 5
#                 timeout = 4
#                 matcher = "200-308"
#   }
# }

# resource "aws_lb_target_group_attachment" "target1" {
#   target_group_arn = aws_lb_target_group.target-grp.arn
#   target_id        = aws_instance.webserver1.id
#   port             = 80
#   }
  
# resource "aws_lb_target_group_attachment" "target2" {
#   target_group_arn = aws_lb_target_group.target-grp.arn
#   target_id        = aws_instance.webserver2.id
#   port             = 80
#   }

# resource "aws_lb_listener" "elb_listener" {
#   load_balancer_arn = aws_lb.http_elb.arn
#   port              = "80"
#   protocol          = "HTTP"
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.target-grp.arn
#   }
# }

# # 12. Output the dns name

# output "lb_hostname_http" {
#   value = aws_lb.http_elb.dns_name
# }

output "webserver_hostname" {
     value = aws_instance.webserver1.public_ip
}

# output "natgw_hostname" {
#     value = aws_nat_gateway.nat-gw.dns_name
# }
