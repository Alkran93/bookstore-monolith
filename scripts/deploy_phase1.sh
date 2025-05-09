#!/bin/bash
set -e

# Colored output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}BookStore Phase 1 Deployment Script${NC}"
echo "----------------------------------------"

# Define variables
STACK_NAME="bookstore-phase1"
TEMPLATE_FILE="../infra/phase1.yaml"
KEY_NAME="bookstore-key"  # Replace with your EC2 key pair name
REGION="us-east-1"        # AWS Academy typically uses us-east-1

# Check if key pair exists, if not create one
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION &> /dev/null; then
    echo -e "${YELLOW}Key pair $KEY_NAME does not exist, creating it...${NC}"
    aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text --region $REGION > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo -e "${GREEN}Created key pair $KEY_NAME and saved to ${KEY_NAME}.pem${NC}"
else
    echo -e "${GREEN}Using existing key pair $KEY_NAME${NC}"
fi

# Deploy the CloudFormation stack
echo -e "${YELLOW}Deploying CloudFormation stack $STACK_NAME...${NC}"
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters ParameterKey=KeyName,ParameterValue=$KEY_NAME \
                 ParameterKey=InstanceType,ParameterValue=t2.micro \
    --capabilities CAPABILITY_IAM \
    --region $REGION

echo -e "${YELLOW}Waiting for stack creation to complete...${NC}"
aws cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME \
    --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Stack creation completed successfully!${NC}"
    
    # Get outputs from the stack
    PUBLIC_IP=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PublicIP'].OutputValue" --output text --region $REGION)
    INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" --output text --region $REGION)
    
    echo -e "${GREEN}Deployment Information:${NC}"
    echo "Instance ID: $INSTANCE_ID"
    echo "Public IP: $PUBLIC_IP"
    echo "HTTP URL: http://$PUBLIC_IP"
    
    echo -e "${YELLOW}Waiting for instance to initialize (this may take a few minutes)...${NC}"
    sleep 180  # Wait for user-data script to complete
    
    echo -e "${GREEN}Testing HTTP connection:${NC}"
    curl -s -o /dev/null -w "%{http_code}" http://$PUBLIC_IP
    
    echo -e "\n${YELLOW}Next Steps for Manual Configuration:${NC}"
    echo "1. SSH to your instance: ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP"
    echo "2. Check Docker containers: docker ps"
    echo "3. To obtain SSL certificate manually, run: sudo certbot --nginx -d yourdomain.com"
    echo "4. For HTTPS validation: curl -vk https://yourdomain.com"
else
    echo -e "${RED}Stack creation failed!${NC}"
    aws cloudformation describe-stack-events \
        --stack-name $STACK_NAME \
        --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].ResourceStatusReason" \
        --output text \
        --region $REGION
fi
