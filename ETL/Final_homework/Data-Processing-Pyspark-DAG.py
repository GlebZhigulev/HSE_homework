import uuid
import datetime

from airflow import DAG
from airflow.providers.yandex.operators.dataproc import (
    DataprocCreateClusterOperator,
    DataprocCreatePysparkJobOperator,
    DataprocDeleteClusterOperator,
)


YC_DP_FOLDER_ID = "b1ggp9gi31i619gfblmm"          # ID каталога, где создаётся кластер
YC_DP_SUBNET_ID = "e9b8tfth1j51c8mreb69"          # подсеть (с NAT в интернет)
YC_DP_SA_ID = "ajeiergfoigiadf5190r"     # сервисный аккаунт для кластера
YC_DP_AZ = "ru-central1-a"               # зона доступности

YC_SOURCE_BUCKET = "bucketairflow23"   
YC_DP_LOGS_BUCKET = "etl-logs"     
PYSPARK_SCRIPT = f"s3a://{YC_SOURCE_BUCKET}/scripts/process_applications.py"


with DAG(
    dag_id="data_processing_pyspark",
    schedule_interval="@daily",          
    start_date=datetime.datetime(2026, 1, 1),
    catchup=False,
    tags=["data-processing", "etl"],
) as dag:

    create_cluster = DataprocCreateClusterOperator(
        task_id="create-cluster",
        folder_id=YC_DP_FOLDER_ID,
        cluster_name=f"tmp-dp-{uuid.uuid4()}",
        cluster_description="Временный кластер для PySpark-задания",
        subnet_id=YC_DP_SUBNET_ID,
        service_account_id=YC_DP_SA_ID,
        zone=YC_DP_AZ,
        s3_bucket=YC_DP_LOGS_BUCKET,
        cluster_image_version="2.1",
        services=["YARN", "SPARK", "HDFS", "MAPREDUCE"],
        ssh_public_keys=["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9l37ftECl+Aij6BUcKh0K2W2Tv42A03rvT4/03uKL+ obliw@Home"],
        masternode_resource_preset="s3-c2-m8",
        masternode_disk_type="network-hdd",
        masternode_disk_size=20,
        datanode_resource_preset="s3-c4-m16",
        datanode_disk_type="network-hdd",
        datanode_disk_size=20,
        datanode_count=1,
        computenode_count=0,
        connection_id="yandexcloud_default",
    )

    run_pyspark = DataprocCreatePysparkJobOperator(
        task_id="run-pyspark-job",
        main_python_file_uri=PYSPARK_SCRIPT,
        connection_id="yandexcloud_default",
    )

    delete_cluster = DataprocDeleteClusterOperator(
        task_id="delete-cluster",
        trigger_rule="all_done",
        connection_id="yandexcloud_default",
    )

    create_cluster >> run_pyspark >> delete_cluster
