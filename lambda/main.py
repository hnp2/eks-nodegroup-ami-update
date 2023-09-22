import os
import boto3
import logging

FORMAT = '%(asctime)s %(levelname)s %(message)s'
logging.basicConfig(format=FORMAT)
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_latest_ami_for_eks(eks_version: str, arch: str):
    client = boto3.client('ssm')
    ami_name = 'amazon-linux-2-arm64' if arch == 'arm64' else 'amazon-linux-2'
    response = client.get_parameter(
        Name=f'/aws/service/eks/optimized-ami/{eks_version}/{ami_name}/recommended/image_id',
        WithDecryption=True
    )

    if 'Parameter' in response:
        return response['Parameter']['Value']
    else:
        return None


def describe_ami(image_id):
    client = boto3.client('ec2')
    response = client.describe_images(
        ImageIds=[
            image_id,
        ],
    )

    if 'Images' in response:
        return response['Images'][0]
    else:
        return None


def list_clusters():
    client = boto3.client('eks')
    response = client.list_clusters()

    if 'clusters' in response:
        return response['clusters']
    else:
        return None


def get_cluster_by_name(cluster_name: str):
    client = boto3.client('eks')
    response = client.describe_cluster(name=cluster_name)

    if 'cluster' in response:
        return response['cluster']
    else:
        return None


def get_nodegroups(cluster_name: str):
    client = boto3.client('eks')
    response = client.list_nodegroups(clusterName=cluster_name)

    if 'nodegroups' in response:
        return response['nodegroups']
    else:
        return []


def get_nodegroup_launch_template(cluster_name: str, nodegroup_name: str):
    client = boto3.client('eks')
    response = client.describe_nodegroup(
        clusterName=cluster_name,
        nodegroupName=nodegroup_name)

    if 'nodegroup' in response and 'launchTemplate' in response['nodegroup']:
        return response['nodegroup']['launchTemplate']['id']
    else:
        return None


def update_launch_template(launch_template_id: str, image_id: str, launch_template_data: dict):
    client = boto3.client('ec2')
    launch_template_data['ImageId'] = image_id
    response = client.create_launch_template_version(
        LaunchTemplateId=launch_template_id,
        VersionDescription=f'Patch AMI {image_id}',
        LaunchTemplateData=launch_template_data,
    )

    return response['LaunchTemplateVersion']['LaunchTemplateId']


def get_launch_template_ami(launch_template_id: str):
    client = boto3.client('ec2')
    response = client.describe_launch_template_versions(
        LaunchTemplateId=launch_template_id,
    )

    if 'LaunchTemplateVersions' in response and len(response['LaunchTemplateVersions']) > 0:
        return response['LaunchTemplateVersions'][0]['LaunchTemplateData']['ImageId']
    else:
        return None


def get_launch_template_data(launch_template_id: str):
    client = boto3.client('ec2')
    response = client.describe_launch_template_versions(
        LaunchTemplateId=launch_template_id,
    )

    if 'LaunchTemplateVersions' in response and len(response['LaunchTemplateVersions']) > 0:
        return response['LaunchTemplateVersions'][0]['LaunchTemplateData']
    else:
        return None


def update_nodegroup(
        cluster_name: str, nodegroup_name: str, launch_template_id: str, force_update: bool = True):
    client = boto3.client('eks')
    response = client.update_nodegroup_version(
        clusterName=cluster_name,
        nodegroupName=nodegroup_name,
        force=force_update,
        launchTemplate={
            'id': launch_template_id,
        }
    )

    return response['update']['id']


def main(cluster_name: str = None):
    # Get the cluster details
    cluster = get_cluster_by_name(cluster_name)

    if cluster:
        logger.info("Cluster Name: %s", cluster['name'])
        logger.info("Cluster ARN: %s", cluster['arn'])
        logger.info("Cluster Version: %s", cluster['version'])
        logger.info("Cluster Status: %s", cluster['status'])

        # Get the associated node groups
        nodegroups = get_nodegroups(cluster_name)

        if len(nodegroups) > 0:
            logger.info("Associated Node Groups found")

            for nodegroup in nodegroups:
                logger.info("Node Group Name: %s", nodegroup)

                # Get the launch template for the node group
                launch_template_id = get_nodegroup_launch_template(cluster_name, nodegroup)

                if launch_template_id:
                    logger.info("Launch Template ID: %s", launch_template_id)

                    launch_template_ami = get_launch_template_ami(launch_template_id)
                    current_ami_parameters = describe_ami(launch_template_ami)

                    # Get the latest AMI for the EKS version
                    latest_ami = get_latest_ami_for_eks(cluster['version'], current_ami_parameters['Architecture'])

                    if latest_ami:
                        if latest_ami != launch_template_ami:
                            logger.info("Launch template uses AMI: %s, the latest AMI: %s, updating launch template.",
                                        latest_ami, launch_template_ami)

                            # Fetch latest template configuration
                            launch_template_data = get_launch_template_data(launch_template_id)

                            # Update the launch template with the latest AMI
                            updated_launch_template_id = update_launch_template(
                                launch_template_id, latest_ami, launch_template_data)

                            logger.info("Updating nodegroup %s to use launch template %s.",
                                        nodegroup, updated_launch_template_id)

                            # Update the nodegroup with the latest launch template
                            updated_nodegroup_id = update_nodegroup(cluster_name, nodegroup, updated_launch_template_id)

                            logger.info("Node Group %s updated with the latest AMI.", updated_nodegroup_id)
                        else:
                            logger.info("Launch template is already using the latest AMI.")
                    else:
                        logger.info(f'No AMI found for EKS version {cluster["version"]}.')
                else:
                    logger.info("Node Group does not have associated launch template.")

                logger.info("---")
        else:
            logger.info("No associated node groups found.")
    else:
        logger.info("Cluster not found.")


def lambda_handler(event, context):
    if os.getenv('EKS_CLUSTER_NAME', None):
        logger.info("Found cluster settings.")
        main(os.getenv('EKS_CLUSTER_NAME'))
    else:
        logger.info("Cluster name not specified, scanning all clusters.")
        for cluster in list_clusters():
            main(cluster)

    return True


if __name__ == '__main__':
    lambda_handler(None, None)
