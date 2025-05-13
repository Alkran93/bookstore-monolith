# EFS File System
resource "aws_efs_file_system" "bookstore_efs" {
  creation_token = "${var.project_name}-EFS"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.project_name}-EFS"
  }
}

# EFS Mount Targets (one per subnet)
resource "aws_efs_mount_target" "bookstore_efs_mt" {
  count           = length(data.aws_subnets.default.ids)
  file_system_id  = aws_efs_file_system.bookstore_efs.id
  subnet_id       = element(data.aws_subnets.default.ids, count.index)
  security_groups = [aws_security_group.efs_sg.id]
}
