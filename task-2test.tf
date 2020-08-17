provider "aws" {
  region     = "ap-south-1"
  profile    = "Ddhruv"
 
}


variable "key_name" {}

resource "tls_private_key" "example" {
  algorithm   = "RSA"
  rsa_bits = "4096"
}


resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.example.public_key_openssh
}

resource "aws_security_group" "sec_g" {
  name        = "sec_g"
  
  vpc_id      = "vpc-101a0678"

  ingress {
    
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
ingress {
    
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }



  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "sec_g"
  }
}


resource "aws_instance" "ins1" {
	ami  		= "ami-0447a12f28fddb066"
	instance_type   = "t2.micro"
	key_name 	= aws_key_pair.generated_key.key_name
	security_groups = ["sec_g"]

	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = tls_private_key.example.private_key_pem
		host = aws_instance.ins1.public_ip
	}

	provisioner "remote-exec" {
	  inline = [
		"sudo yum install httpd php git -y",
		"sudo systemctl restart httpd",
		"sudo systemctl enable httpd",
		]
	}
		

	tags = {
	  Name = "testos"
	}
}

output "myloc" {
	value = aws_instance.ins1.availability_zone
}

/*----------------------------------------------------------------------------*/

resource "aws_efs_file_system" "efs1" {
  creation_token = "my-product"

  tags = {
    Name = "MyProduct"
  }
}


resource "aws_efs_mount_target" "alpha" {
  					#subnet_id = "subnet-97ea81db"to be checked and hardcoded
  file_system_id = "${aws_efs_file_system.efs1.id}"
  subnet_id = "${aws_subnet.alpha.id}"
  security_groups= ["sec_g"]
}

resource "aws_subnet" "alpha"{
vpc_id = "vpc-101a0678"
availability_zone = "ap-south-1b"
cidr_block = "172.31.48.0/20"

}


/*output "myefs1" {
	value = ws_efs_file_system.efs1.id
}
*/
/*----------------------------------------------------------------------------*/
output "myy_ip" {
	value = aws_instance.ins1.public_ip
	}

resource "null_resource" "nulllocal2" {
	provisioner "local-exec" {
		command = "echo ${aws_instance.ins1.public_ip} > publicip.txt"
	}
}


resource "null_resource" "nullremote3" {
	/*depends_on = [
		aws_efs_mount_target.alpha,
	]*/
	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = tls_private_key.example.private_key_pem
		host = aws_instance.ins1.public_ip
	}
	
	provisioner "remote-exec" {
		
			inline = [
			"sudo mkfs.ext4  /dev/xvdh",
			"sudo mount  /dev/xvdh  /var/www/html",
			"sudo git clone https://github.com/Ddhruv-IOT/server-test.git /var/www/html/"
			 ]
			
 	}
}

resource "null_resource" "nulllocal1"  {


depends_on = [
      aws_cloudfront_distribution.s3_distribution,
  ]

	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.ins1.public_ip}"
  	}
}

resource "aws_s3_bucket" "image-bucket" {
	bucket = "webserver-images-test-dd-dd"
	acl    = "public-read"
provisioner "local-exec" {
		command = "git clone https://github.com/Ddhruv-IOT/server-image"
    }
provisioner "local-exec" {
	when = destroy
	command = "echo Y | rmdir /s server-image"
	}	
}

resource "aws_s3_bucket_object" "image-upload" {
	bucket = aws_s3_bucket.image-bucket.bucket
	key    = "stest.jpg"
	source = "server-image/stest.jpg"
	acl    = "public-read"
}


variable "var1" {default = "S3-"}
locals {
    s3_origin_id = "${var.var1}${aws_s3_bucket.image-bucket.bucket}"
    image_url = "${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.image-upload.key}"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
    default_cache_behavior {
        allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
    }
enabled             = true
origin {
        domain_name = aws_s3_bucket.image-bucket.bucket_domain_name
        origin_id   = local.s3_origin_id
    }
restrictions {
        geo_restriction {
        restriction_type = "none"
        }
    }
viewer_certificate {
        cloudfront_default_certificate = true
    }
connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.ins1.public_ip
        port    = 22
        private_key = tls_private_key.example.private_key_pem
    }
provisioner "remote-exec" {
        inline  = [
            # "sudo su << \"EOF\" \n echo \"<img src='${self.domain_name}'>\" >> /var/www/html/test.html \n \"EOF\""
            "sudo su << EOF",
            "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.image-upload.key}' height=200px width=200px >\" >> /var/www/html/index.php",
            "EOF"
        ]
    }
}


#aws_instance.example.id 