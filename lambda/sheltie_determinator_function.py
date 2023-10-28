import json
import boto3

rekognition = boto3.client('rekognition')

def lambda_handler(event, context):
    image_content = event['body']

    s3_key = "uploaded_sheltie_image.jpg"
    bucket_name = "sheltie_image_comparison_bucket"

    s3_client = boto3.client('s3')
    s3_client.put_object(Bucket=bucket_name, Key=s3_key, Body=image_content)

    response_message = "You're dang right that is a Sheltie!" if determine_if_sheltie(bucket_name,s3_key) else "Sorry, that is not a Sheltie."
    
    return {
        'statusCode': 200,
        'body': response_message
    }


def determine_if_sheltie(bucket_name, photo_name):
    try:
        response = rekognition.detect_labels(
            Image={
                'S3Object': {
                    'Bucket': bucket_name,
                    'Name': photo_name
                }
            },
            MaxLabels=10
        )
        return any(label['Name'].lower() == 'sheltie' or label['Name'].lower() == 'shetland sheepdog' for label in response['Labels'])
    except Exception as e: 
        return False    
    
