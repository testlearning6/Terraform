# Create a VPC
# ----------------------------------------
resource "aws_vpc" "MyDemoMumbai" {
  cidr_block = "${var.vpc_cidr}"
  instance_tenancy = "default"
	
tags = {
   Name = "MyDemoMumbai"
}
}


# Create a PubSubnet1
# ---------------------------------------
resource "aws_subnet" "Pub1Sub" {
 vpc_id = aws_vpc.MyDemoMumbai.id
 cidr_block = "${var.pub1subnet_cidr}"
 availability_zone = "ap-south-1a"

tags = {
  Name = "MyPubSub1"
}
}

# Create a PubSubnet2
# --------------------------------------
resource "aws_subnet" "Pub2Sub" {
 vpc_id = aws_vpc.MyDemoMumbai.id
 cidr_block = "${var.pub2subnet_cidr}"
 availability_zone = "ap-south-1b"

tags = {
  Name = "MyPubSub2"
}
}

# Create a InternetGateway
# ---------------------------------------
resource "aws_internet_gateway" "MyMumbai" {
 vpc_id = aws_vpc.MyDemoMumbai.id
 
tags = {
  Name = "MyMumbai"
}
}

# Creating a PubRouteTable with access from anywhere and associating Pub 2Subnets
# --------------------------------------------------------------------------------
resource "aws_route_table" "PubRT" {
 vpc_id = aws_vpc.MyDemoMumbai.id

route {
 cidr_block = "0.0.0.0/0"
 gateway_id = aws_internet_gateway.MyMumbai.id
}

tags = {
 Name = "MyPubRT"
}
}

resource "aws_route_table_association" "aPubRT" {
  subnet_id = aws_subnet.Pub1Sub.id
  route_table_id = aws_route_table.PubRT.id
}

resource "aws_route_table_association" "bPubRT" {
  subnet_id = aws_subnet.Pub2Sub.id
  route_table_id = aws_route_table.PubRT.id
}

# Creating a Security Group
# ------------------------------------------------------------------
resource "aws_security_group" "allow_http_ssh" {
  name        = "allow_http_ssh"
  description = "Allow HTTP_SSH inbound traffic"
  vpc_id      = aws_vpc.MyDemoMumbai.id

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow_HTTP_SSH"
  }
}


# Creating Instances with Apache
# ------------------------------------------------------
resource "aws_instance" "MyInstance1" {
 ami = "${var.ec2_image}"
 instance_type = "t2.micro"
 key_name = "Desktop"
 availability_zone = "ap-south-1a"
 user_data = "${file("installapache.sh")}"
 associate_public_ip_address = true
 subnet_id = aws_subnet.Pub1Sub.id
 vpc_security_group_ids = [aws_security_group.allow_http_ssh.id]

tags = {
 Name = "MyInstance1"
}
}

resource "aws_instance" "MyInstance2" {
 ami = "${var.ec2_image}"
 instance_type = "t2.micro"
 key_name = "Desktop"
 availability_zone = "ap-south-1b"
 user_data = "${file("installapache.sh")}"
 associate_public_ip_address = true
 subnet_id = aws_subnet.Pub2Sub.id
 vpc_security_group_ids = [aws_security_group.allow_http_ssh.id]

tags = {
 Name = "MyInstance2"
}
}


# Creating a Target Group
# ------------------------------------------------------
resource "aws_lb_target_group" "MyMumbaiTG" {
 health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name     = "MyMumbaiTG"
  port     = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = aws_vpc.MyDemoMumbai.id
}


# Attaching the Target Group 
# ------------------------------------------------------
resource "aws_lb_target_group_attachment" "my-alb-target-group-attachment1" {
  target_group_arn = "${aws_lb_target_group.MyMumbaiTG.arn}"
  target_id        = aws_instance.MyInstance1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "my-alb-target-group-attachment2" {
  target_group_arn = "${aws_lb_target_group.MyMumbaiTG.arn}"
  target_id        = aws_instance.MyInstance2.id
  port             = 80
}


# Creating ALB
# -----------------------------------------------------
resource "aws_lb" "MyMumbaiALB" {
  name               = "MyMumbaiALB"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["${aws_subnet.Pub2Sub.id}", "${aws_subnet.Pub1Sub.id}"]
  enable_deletion_protection = true
  security_groups    = [aws_security_group.allow_http_ssh.id]

  tags = {
    Environment = "production"
  }
}

# Providing LB Listener
# -----------------------------------------------------
resource "aws_lb_listener" "my-test-alb-listener" {
  load_balancer_arn = "${aws_lb.MyMumbaiALB.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.MyMumbaiTG.arn}"
  }
}
