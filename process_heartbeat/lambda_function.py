import json
import os
import logging
import socket
from typing import Any
import boto3
from boto3.exceptions import Boto3Error
from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO)

max_msg_count = int(os.getenv('MAX_MSG_COUNT', 1))
queue_url = os.getenv('HEARTBEAT_QUEUE_URL')
region = os.getenv('AWS_REGION')
table_name = os.getenv('TABLE_NAME')

if not queue_url:
    logging.fatal("HEARTBEAT_QUEUE_URL environment variable is required")
    raise ValueError("HEARTBEAT_QUEUE_URL environment variable is required")

if not region:
    logging.fatal("AWS_REGION environment variable is required")
    raise ValueError("AWS_REGION environment variable is required")

if not table_name:
    logging.fatal("TABLE_NAME environment variable is required")
    raise ValueError("TABLE_NAME environment variable is required")

hostname = socket.gethostname()

def process_message(client: Any) -> bool:
    try:
        response = client.receive_message(
            QueueUrl=queue_url,
            MaxNumberOfMessages=max_msg_count,
            WaitTimeSeconds=10
        )
        messages = response.get('Messages', [])
        if messages:
            for message in messages:
                logging.info("Received message: %s", message['Body'])
                try:
                    table_item = json.loads(message['Body'])
                    if not write_dynamodb_table_item(table_item):
                        return False
                except (json.JSONDecodeError, ValueError) as e:
                    logging.error("Failed to decode message body: %s", e)
                    return False

                client.delete_message(
                    QueueUrl=queue_url,
                    ReceiptHandle=message['ReceiptHandle']
                )
                logging.info("Message processed, removing from queue")
        else:
            logging.info("No message(s) received")
        return True
    except (Boto3Error, ClientError) as e:
        logging.error("Failed to receive message: %s", e)
        return False

def write_dynamodb_table_item(data: dict) -> bool:
    try:
        dynamodb = boto3.resource('dynamodb', region_name=region)
        table = dynamodb.Table(table_name)

        response = table.put_item(
            Item=data,
            ConditionExpression="attribute_not_exists(#s) AND attribute_not_exists(#t) OR #r <> :r",
            ExpressionAttributeNames={
                '#s': 'source',
                '#t': 'timestamp',
                '#r': 'region'
            },
            ExpressionAttributeValues={':r': data['region']}
        )
        logging.info("Data written to DynamoDB: %s", response)
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            logging.info("Item exists, skipping write.")
            return True
        else:
            logging.error("Failed to write to DynamoDB: %s", e.response['Error']['Message'])
            return False
    except Exception as e:
        logging.error("Unexpected error: %s", str(e))
        return False

def lambda_handler(event: dict, context: Any) -> dict:
    try:
        client = boto3.client('sqs', region_name=region)
        if process_message(client):
            return {
                'statusCode': 200,
                'body': 'Message processed successfully'
            }
        else:
            return {
                'statusCode': 500,
                'body': 'Failed to process message'
            }
    except Exception as e:
        logging.error("Lambda function error: %s", e)
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }

if __name__ == '__main__':
    client = boto3.client('sqs', region_name=region)
    if not process_message(client):
        logging.error("Failed to process message.")
