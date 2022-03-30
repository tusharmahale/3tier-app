resource "aws_rds_cluster" "default" {
  cluster_identifier      = "aurora-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = "13.3"
  availability_zones      = var.azs
  database_name           = "mytestdb"
  master_username         = "mytestuser"
  master_password         = "changemepls"
  backup_retention_period = 5
  preferred_backup_window = "02:00-04:00"
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [
    module.eks.cluster_primary_security_group_id,
  ]
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  count                = 2
  identifier           = "aurora-instance-${count.index}"
  cluster_identifier   = aws_rds_cluster.default.id
  instance_class       = "db.t3.medium"
  engine               = aws_rds_cluster.default.engine
  engine_version       = aws_rds_cluster.default.engine_version
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = module.vpc.private_subnets
}
