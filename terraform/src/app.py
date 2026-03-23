import json
import os
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

glue = boto3.client("glue")
GLUE_JOB_NAME = os.environ.get("GLUE_JOB_NAME")


def lambda_handler(event, context):
    try:
        logger.info(f"Received event: {json.dumps(event)}")

        response = glue.start_job_run(
            JobName=GLUE_JOB_NAME
        )

        job_run_id = response["JobRunId"]

        logger.info(f"Started Glue job: {job_run_id}")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Glue job started",
                "jobRunId": job_run_id
            })
        }

    except Exception as e:
        logger.error(str(e), exc_info=True)
        raise
