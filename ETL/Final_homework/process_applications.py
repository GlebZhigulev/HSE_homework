"""
PySpark-задание для Yandex Data Processing.

Читает CSV с кредитными заявками из Object Storage (s3a://...),
строит несколько витрин-агрегатов и пишет результат в Parquet
обратно в Object Storage.

Задание запускается оператором DataprocCreatePysparkJobOperator из DAG.
Кластер Data Processing уже настроен на доступ к Object Storage через
сервисный аккаунт, поэтому пути s3a://<bucket>/... работают напрямую.
"""

from pyspark.sql import SparkSession, functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, BooleanType,
)

INPUT_PATH = "s3a://bucketairflow23/applications/"      
OUTPUT_PATH = "s3a://bucketairflow23/result/"         


schema = StructType([
    StructField("application_id",       StringType(),  True),
    StructField("event_time",           StringType(),  True),
    StructField("customer_id",          StringType(),  True),
    StructField("region_code",          StringType(),  True),
    StructField("product_type",         StringType(),  True),
    StructField("requested_amount",     IntegerType(), True),
    StructField("term_months",          IntegerType(), True),
    StructField("credit_score",         IntegerType(), True),
    StructField("risk_level",           StringType(),  True),
    StructField("decision_status",      StringType(),  True),
    StructField("approved_amount",      IntegerType(), True),
    StructField("channel",              StringType(),  True),
    StructField("employee_review_flag", BooleanType(), True),
    StructField("processing_time_sec",  IntegerType(), True),
])


def main():
    spark = (
        SparkSession.builder
        .appName("process_applications")
        .getOrCreate()
    )

    df = (
        spark.read
        .option("header", True)
        .schema(schema)
        .csv(INPUT_PATH)
    )

    df = df.withColumn("event_ts", F.to_timestamp("event_time", "yyyy-MM-dd HH:mm:ss")) \
           .withColumn("event_date", F.to_date("event_ts"))

    total_rows = df.count()
    print(f"[INFO] Прочитано строк: {total_rows}")

  
    by_region_product = (
        df.groupBy("region_code", "product_type")
          .agg(
              F.count("*").alias("applications"),
              F.sum(F.when(F.col("decision_status") == "approved", 1).otherwise(0)).alias("approved_cnt"),
              F.round(
                  F.avg(F.when(F.col("decision_status") == "approved", 1.0).otherwise(0.0)), 4
              ).alias("approval_rate"),
              F.round(F.avg("credit_score"), 1).alias("avg_credit_score"),
              F.sum("requested_amount").alias("total_requested"),
              F.sum("approved_amount").alias("total_approved"),
          )
    )

    by_day = (
        df.groupBy("event_date")
          .agg(
              F.count("*").alias("applications"),
              F.round(F.avg("processing_time_sec"), 2).alias("avg_processing_sec"),
              F.sum("approved_amount").alias("total_approved"),
          )
          .orderBy("event_date")
    )

    by_risk_channel = (
        df.groupBy("risk_level", "channel")
          .agg(
              F.count("*").alias("applications"),
              F.round(F.avg("credit_score"), 1).alias("avg_credit_score"),
          )
    )

    by_region_product.write.mode("overwrite").parquet(OUTPUT_PATH + "by_region_product/")
    by_day.write.mode("overwrite").parquet(OUTPUT_PATH + "by_day/")
    by_risk_channel.write.mode("overwrite").parquet(OUTPUT_PATH + "by_risk_channel/")

    print("[INFO] Витрины записаны в:", OUTPUT_PATH)
    spark.stop()


if __name__ == "__main__":
    main()
