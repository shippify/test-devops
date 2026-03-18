"""
Lambda that tries to:
1. List S3 buckets (will fail: Access Denied if role has no s3:ListAllMyBuckets)
2. Call an external API (will fail: timeout if Lambda is in VPC with no NAT)
"""
import json
import urllib.request
import boto3
import os

BUCKET_NAME = os.environ.get("BUCKET_NAME", "")
EXTERNAL_API_URL = os.environ.get("EXTERNAL_API_URL", "https://httpbin.org/get")


def handler(event, context):
    result = {"s3_list": None, "external_api": None, "errors": []}

    # 1. Try to list ALL S3 buckets (expected to fail without s3:ListAllMyBuckets)
    try:
        s3 = boto3.client("s3")
        buckets_resp = s3.list_buckets()
        result["s3_list"] = {
            "buckets": [b["Name"] for b in buckets_resp.get("Buckets", [])],
        }

        # Also list objects from our target bucket (expected to fail without s3:ListBucket)
        if BUCKET_NAME:
            response = s3.list_objects_v2(Bucket=BUCKET_NAME, MaxKeys=5)
            result["s3_list"]["bucket_objects"] = {
                "bucket": BUCKET_NAME,
                "key_count": response.get("KeyCount", 0),
                "keys": [obj["Key"] for obj in response.get("Contents", [])],
            }
    except Exception as e:
        result["errors"].append(f"s3: {type(e).__name__}: {str(e)}")

    # 2. Try to call external API
    try:
        req = urllib.request.Request(EXTERNAL_API_URL, method="GET")
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = resp.read().decode()
            result["external_api"] = {"status": resp.status, "body_preview": body[:200]}
    except Exception as e:
        result["errors"].append(f"api: {type(e).__name__}: {str(e)}")

    return {
        "statusCode": 200,
        "body": json.dumps(result, indent=2),
    }
