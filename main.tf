#creating_vpc


resource "aws_vpc" "wordpressvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "wordpressvpc"
  }
enable_dns_hostnames = "true"
}




#creating_public_subnet

resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.wordpressvpc.id
  cidr_block = "10.0.1.0/24"
 availability_zone = "us-east-1a"

  tags = {
    Name = "public"
  }

}

#creating_private_subnet


resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.wordpressvpc.id
  cidr_block = "10.0.2.0/24"
availability_zone = "us-east-1b"

  tags = {
    Name = "private"
  }
}




#creating_securitygroup

resource "aws_security_group" "wordpresstask-sg" {
  name        = "wordpresstask-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.wordpressvpc.id
 
  ingress {
    description = "TLS from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  tags = {
    Name = "wordpress-sg"
  }
 
}





 
#creating_internet-gateway

resource "aws_internet_gateway" "mywpigw" {
  vpc_id = aws_vpc.wordpressvpc.id
 
  tags = {
    Name = "mywpigw"
  }
}






#creating_route_table
 
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.wordpressvpc.id
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mywpigw.id
  }
 
 
 
  tags = {
    Name = "public-rt"
  }
}





#associating_route_table

resource "aws_route_table_association" "publicassociation" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-rt.id
}






#creating_keypair


resource "aws_key_pair" "mynewwpkey" {
  key_name   = "mynewwpkey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMMWRf067py0ArZXihJWaPcOYZV0sLloFelt7Ff+15edLVWwrbt5F97KctPXGIi6rlLDV4M8EPjI7NvHy0U/lbc+RQuaxoqHP5FpCQRK15+VmSCNQB34yhUV0/QQ+qe4o8MLzHGyWLE8M2rFYbm/bTAmB9XqWpFOkKvF9zT7pSVlC4lcoi4vA8EVD2n+Ag0GRXV6ZLQGAzVtxwnwsU5KNubn5Jc5LjK0U84ybw5U4DNkyuTMWtzTqjLJABWoWgkZA2bS+KRAE+AzdRdJztwAlxYE9javy+gCeFMwzQtHeeziSmfZZQ+IFINjO7L2cqw+C+VitMi0w/XMTCEnRX9pn3 root@ip-172-31-46-224.us-west-2.compute.internal"
}





#creating_asg


resource "aws_launch_configuration" "mylaunchconfiguration" {
  image_id               = "ami-0742b4e673072066f"
  instance_type          = "t2.large"
  security_groups        = [aws_security_group.wordpresstask-sg.id]

  key_name               = "mynewwpkey"
  user_data = file("script.sh")

  lifecycle {
    create_before_destroy = true
  }

associate_public_ip_address = true
}



#Creating AutoScaling Group
resource "aws_autoscaling_group" "myasg" {
  launch_configuration = aws_launch_configuration.mylaunchconfiguration.id
 load_balancers = [
    aws_elb.web_elb.id
  ]
 vpc_zone_identifier  = [aws_subnet.public-subnet.id]
  min_size = 1
  max_size = 2
  
  health_check_type = "ELB"
  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
}




#Creating load-balancer

resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    aws_security_group.wordpresstask-sg.id
  ]
  subnets = [
    aws_subnet.public-subnet.id,
    aws_subnet.private-subnet.id
  ]

  cross_zone_load_balancing   = true

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

}


# Launching db_subnet_group

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.public-subnet.id,aws_subnet.private-subnet.id]

  tags = {
    Name = "My DB subnet group"
  }
}






# Launching RDS db instance

resource "aws_db_instance" "myrds" {
  allocated_storage    = 20
  max_allocated_storage = 100
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0.20"
  instance_class       = "db.t2.medium"

db_subnet_group_name    = aws_db_subnet_group.default.id
  name                 = "karandeepsingh"
  username             = "karandeepsingh"
  password             = "karandeepsingh12345"
  parameter_group_name = "default.mysql8.0"
  publicly_accessible = false
 vpc_security_group_ids     = [aws_security_group.wordpresstask-sg.id]
  
  skip_final_snapshot = true 

}



