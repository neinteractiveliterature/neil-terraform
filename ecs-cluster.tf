# resource "aws_cloudformation_stack" "neil_production" {
#   name = "neil-production"
# }

# resource "aws_autoscaling_group" "neil_production" {
#   name = "neil-production"
#   min_size = 0
#   max_size = 1

#   availability_zones = [
#     "us-east-1a",
#     "us-east-1b",
#   ]
# }

# resource "aws_ecs_cluster" "neil_production" {
#   name = "neil-production"
# }

# locals {
#   intercode_env = [
#     {
#       name = "DATABASE_URL"
#       value = "postgres://intercode_production:${var.intercode_production_db_password}@${aws_db_instance.intercode_production.endpoint}/intercode_production?sslrootcert=rds-combined-ca-bundle-2019.pem"
#     },
#     { name = "AWS_REGION", value = "us-east-1" },
#     { name = "AWS_ACCESS_KEY_ID", value = aws_iam_access_key.intercode2_production.id },
#     { name = "AWS_REGION", value = data.aws_region.current.name },
#     { name = "AWS_SECRET_ACCESS_KEY", value = aws_iam_access_key.intercode2_production.secret },
#     { name = "AWS_S3_BUCKET", value = aws_s3_bucket.intercode2_production.bucket }
#   ]
#   intercode_image = "neinteractiveliterature/intercode:latest"
# }

# resource "aws_ecs_task_definition" "intercode" {
#   family = "intercode"
#   requires_compatibilities = ["EC2"]
#   container_definitions = jsonencode([
#     {
#       name = "web"
#       command = ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
#       environment = local.intercode_env
#       essential = true
#       image = local.intercode_image
#       logConfiguration = {
#         logDriver = "awslogs"
#         options = {
#           awslogs-group = "/ecs/intercode"
#           awslogs-region = "us-east-1"
#           awslogs-stream-prefix = "ecs"
#         }
#       }
#       memoryReservation = 500
#     },
#     {
#       name = "shoryuken"
#       command = ["bundle", "exec", "shoryuken", "--rails", "-C", "config/shoryuken.yml"]
#       environment = local.intercode_env,
#       essential = true,
#       image = local.intercode_image
#       logConfiguration = {
#         logDriver = "awslogs"
#         options = {
#           awslogs-group = "/ecs/intercode"
#           awslogs-region = "us-east-1"
#           awslogs-stream-prefix = "ecs"
#         }
#       }
#       memoryReservation = 300
#     }
#   ])
# }

# resource "aws_ecs_service" "intercode" {
#   name = "intercode"
#   cluster = aws_ecs_cluster.neil_production.name
#   task_definition = "${aws_ecs_task_definition.intercode.id}:${aws_ecs_task_definition.intercode.id}"
#   launch_type = "EC2"

#   desired_count = 1
#   health_check_grace_period_seconds = 0

#   deployment_controller {
#     type = "ECS"
#   }

#   ordered_placement_strategy {
#     field = "attribute:ecs.availability-zone"
#     type = "spread"
#   }

#   ordered_placement_strategy {
#     field = "instanceId"
#     type = "spread"
#   }
# }
