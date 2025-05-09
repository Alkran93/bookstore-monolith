#!/bin/bash
set -e

# Colored output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}BookStore Phase 1 Destruction Script${NC}"
echo "----------------------------------------"

# Define variables
STACK_NAME="bookstore-phase1"
REGION="us-east-1"  # AWS Academy typically uses us-east-1

# Check if stack exists
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    echo -e "${YELLOW}Deleting CloudFormation stack $STACK_NAME...${NC}"
    aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
    
    echo -e "${YELLOW}Waiting for stack deletion to complete...${NC}"
    aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Stack deletion completed successfully!${NC}"
    else
        echo -e "${RED}Stack deletion failed!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Stack $STACK_NAME does not exist.${NC}"
fi

echo -e "${GREEN}Resources cleaned up successfully!${NC}"
