import json
import os
import time
import signal
import logging
import socket
from typing import Any
import boto3
from boto3.exceptions import Boto3Error
from botocore.exceptions import ClientError
from threading import Event

logging.basicConfig(level=logging.INFO)

queue_url = os.getenv('HEARTBEAT_QUEUE_URL')
region = os.getenv('AWS_REGION')
run_once = os.getenv('HEARTBEAT_RUN_ONCE', 'false').lower() == 'true'

if not queue_url:
    logging.fatal("HEARTBEAT_QUEUE_URL environment variable is required")
    raise ValueError("HEARTBEAT_QUEUE_URL environment variable is required")

if not region:
    logging.fatal("AWS_REGION environment variable is required")
    raise ValueError("AWS_REGION environment variable is required")

hostname = socket.gethostname()


class HeartbeatMessage:
    def __init__(self, timestamp: str, region: str):
        self.timestamp = timestamp
        self.region = region

    def to_dict(self) -> dict:
        return {
            'source': hostname,
            'timestamp': self.timestamp,
            'region': self.region
        }


def send_heartbeat(client: Any) -> None:
    heartbeat = HeartbeatMessage(
        timestamp=time.strftime('%Y-%m-%dT%H:%M:%S', time.gmtime()),
        region=region
    )

    message_body = json.dumps(heartbeat.to_dict())

    try:
        response = client.send_message(
            QueueUrl=queue_url,
            MessageBody=message_body
        )
        logging.info("Heartbeat sent successfully, MessageId: %s",
                     response.get('MessageId'))
    except (Boto3Error, ClientError) as e:
        logging.error("Failed to send heartbeat: %s", e)


def heartbeat_sender() -> None:
    client = boto3.client('sqs', region_name=region)

    if run_once:
        send_heartbeat(client)
        logging.info("'HEARTBEAT_RUN_ONCE=true' exiting...")
        return

    stop = Event()

    def handle_signal(signum, frame):
        logging.info("Stopping heartbeat sender")
        stop.set()

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    logging.info("Heartbeat sender started")
    while not stop.is_set():
        send_heartbeat(client)
        time.sleep(30)

    logging.info("Exiting...")


def lambda_handler(event: dict, context: Any) -> dict:
    try:
        heartbeat_sender()
        return {
            'statusCode': 200,
            'body': 'Heartbeat sent successfully'
        }
    except Exception as e:
        logging.error("Lambda function error: %s", e)
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }


if __name__ == '__main__':
    heartbeat_sender()
