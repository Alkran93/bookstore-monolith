cat > load_test.sh << 'EOF'
#!/bin/bash
set -e

echo "Realizando pruebas de carga para verificar el Auto Scaling..."

# Verificar que tenemos ab (Apache Benchmark)
if ! command -v ab &> /dev/null; then
    echo "Instalando Apache Benchmark (ab)..."
    sudo yum install -y httpd-tools
fi

# Obtener el ALB DNS
cd infra/phase2
ALB_DNS=$(terraform output -raw load_balancer_dns)
cd ../..

echo "Iniciando prueba de carga contra http://$ALB_DNS/"
echo "Esto generará tráfico para activar el Auto Scaling..."

# Ejecutar 1000 solicitudes con 10 conexiones concurrentes
ab -n 1000 -c 10 http://$ALB_DNS/

echo "Prueba de carga completada."
echo "Verificando el estado del Auto Scaling Group..."

cd infra/phase2
ASG_NAME=$(terraform output -raw autoscaling_group_name)
cd ../..

# Verificar el ASG antes y después de la prueba
echo "Estado del ASG antes de la prueba:"
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $ASG_NAME --query "AutoScalingGroups[0].Instances[*].{InstanceId:InstanceId,LifecycleState:LifecycleState}" --output table

# Esperar a que se complete el escalado
echo "Esperando 5 minutos para que se active el escalado (si es necesario)..."
sleep 300

echo "Estado del ASG después de la prueba:"
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $ASG_NAME --query "AutoScalingGroups[0].Instances[*].{InstanceId:InstanceId,LifecycleState:LifecycleState}" --output table

echo "Verificando métricas de CloudWatch para CPU..."
aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
    --start-time $(date -u -d "30 minutes ago" +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Average \
    --output table

echo "Prueba de carga y verificación completadas."
EOF

chmod +x load_test.sh
