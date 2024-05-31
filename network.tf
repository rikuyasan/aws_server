############################################
# vpc
############################################
resource "aws_vpc" "demo" {
  # 使用するネットワーク範囲の指定
  cidr_block = local.cidr_block
  # テナンシーの設定(デフォルト)
  instance_tenancy = "default"

  # 名前タグ
  tags = {
    "Name" = "${local.pj_name}-vpc"
  }
}

############################################
# subnet
############################################
# public
resource "aws_subnet" "public" {
  for_each          = { for k, v in local.availability_zones : k => v }
  vpc_id            = aws_vpc.demo.id
  cidr_block        = cidrsubnet(local.cidr_block, 8, each.key)
  availability_zone = each.value
  tags = {
    "Name" = "${local.pj_name}-public-subnet${each.key + 1}"
  }
}

# private01
resource "aws_subnet" "private" {
  for_each          = { for k, v in local.availability_zones : k => v }
  vpc_id            = aws_vpc.demo.id
  cidr_block        = cidrsubnet(local.cidr_block, 8, each.key + length(local.availability_zones))
  availability_zone = each.value
  tags = {
    "Name" = "${local.pj_name}-public-subnet${each.key + 1 + length(local.availability_zones)}"
  }
}


############################################
# internet gateway
############################################
resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id
  tags = {
    "Name" = "ecs-demo-igw"
  }
}

############################################
# route table
############################################
# パブリックからigwへのルート
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }
  tags = {
    "Name" = "public_to_igw"
  }
}

# ルーティング(public01_to_igw)
resource "aws_route_table_association" "public" {
  for_each = { for k, v in aws_subnet.public : k => v }

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

############################################
# nat instance
############################################
# 1.セキュリティグループの作成
resource "aws_security_group" "demo" {
  name        = local.instance_name
  description = "only nat instance"
  vpc_id      = aws_vpc.demo.id
}

# インバウンド
resource "aws_security_group_rule" "private_ingress" {
  security_group_id        = aws_security_group.demo.id
  source_security_group_id = aws_security_group.private.id
  from_port                = 0
  protocol                 = "-1"
  to_port                  = 0
  type                     = "ingress"
}

# アウトバウンド
resource "aws_security_group_rule" "private_egress" {
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.demo.id
  from_port         = 0
  protocol          = "-1"
  to_port           = 0
  type              = "egress"
}
# 2.natインスタンスの作成
resource "aws_instance" "demo" {

  tags = {
    "Name" = "natinstance"
  }
  # natインスタンスの選択
  ami           = local.ami
  instance_type = local.instance_type
  # ネットワークの作成
  subnet_id              = values(aws_subnet.public)[0].id
  vpc_security_group_ids = [aws_security_group.demo.id]
  private_ip             = local.nat_cidr_block
  # key name
  key_name = local.instance_name
  # 宛先アドレスが異なる場合にルーティングされないようにする
  source_dest_check = false
  # EBSのルートボリューム設定
  root_block_device {
    delete_on_termination = true
    encrypted             = false
    iops                  = 0
    throughput            = 0
    volume_size           = 8
    volume_type           = "standard"
  }
  # キャパシティ予約
  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }
}

# 3.EIP割り当て
resource "aws_eip" "demo" {
  domain = "vpc"
  tags = {
    "Name" = local.instance_name
  }
  instance                  = aws_instance.demo.id
  associate_with_private_ip = local.nat_cidr_block
}


# 4.ネットワークインターフェイスの作成
resource "aws_network_interface" "demo" {
  subnet_id       = values(aws_subnet.public)[0].id
  private_ips     = [local.nat_cidr_block]
  security_groups = [aws_security_group.demo.id]
  attachment {
    device_index = 0
    instance     = aws_instance.demo.id
  }
  # 宛先アドレスが異なる場合にルーティングされないようにする
  source_dest_check = false
}

# 5.ルートテーブル作成
resource "aws_route_table" "demo" {
  vpc_id = aws_vpc.demo.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.demo.id
  }
  tags = {
    "Name" = "private-to-nat-instance"
  }
}

# 6.ルーティング(private to nat)
resource "aws_route_table_association" "private" {
  for_each       = { for k, v in aws_subnet.private : k => v }
  subnet_id      = each.value.id
  route_table_id = aws_route_table.demo.id
}
