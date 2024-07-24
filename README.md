# python-process-heartbeat

## iam permission

```bash
export AWS_VAULT_FILE_PASSPHRASE="$(cat /root/.awsvaultk)"
```

```bash
aws-vault exec dev -- terraform -chdir=./terraform/01 init
```

```bash
aws-vault exec dev -- terraform -chdir=./terraform/01 apply --auto-approve
```

```bash
source ./terraform/01/terraform.tmp
```

## test send heartbeat app

```bash
export HEARTBEAT_QUEUE_URL=<https://sqs>.<REGION>.amazonaws.com/<ACCOUNT_ID>/<SQS_NAME>
```

```bash
python ./send_heartbeat/lambda_function.py
```

## copy send heartbeat app

```bash
mkdir -p ./terraform/02/external
```

```bash
zip -r -j ./terraform/02/external/send_heartbeat.zip ./send_heartbeat
```

## create send heartbeat lambda

```bash
aws-vault exec dev -- terraform -chdir=./terraform/02 init
```

```bash
aws-vault exec dev -- terraform -chdir=./terraform/02 apply --auto-approve
```

## test process heartbeat app

```bash
export TABLE_NAME=python-process-heartbeat-s938ygt2
```

```bash
python ./process_heartbeat/lambda_function.py
```

## copy process heartbeat app

```bash
mkdir -p ./terraform/03/external
```

```bash
zip -r -j ./terraform/03/external/process_heartbeat.zip ./process_heartbeat
```

## create process heartbeat lambda

```bash
aws-vault exec dev -- terraform -chdir=./terraform/03 init
```

```bash
aws-vault exec dev -- terraform -chdir=./terraform/03 apply --auto-approve
```
