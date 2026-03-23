import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsgluedq.transforms import EvaluateDataQuality
from awsglue.dynamicframe import DynamicFrame
from awsglue import DynamicFrame
from pyspark.sql import functions as SqlFuncs

def sparkSqlQuery(glueContext, query, mapping, transformation_ctx) -> DynamicFrame:
    for alias, frame in mapping.items():
        frame.toDF().createOrReplaceTempView(alias)
    result = spark.sql(query)
    return DynamicFrame.fromDF(result, glueContext, transformation_ctx)
def sparkAggregate(glueContext, parentFrame, groups, aggs, transformation_ctx) -> DynamicFrame:
    aggsFuncs = []
    for column, func in aggs:
        aggsFuncs.append(getattr(SqlFuncs, func)(column))
    result = parentFrame.toDF().groupBy(*groups).agg(*aggsFuncs) if len(groups) > 0 else parentFrame.toDF().agg(*aggsFuncs)
    return DynamicFrame.fromDF(result, glueContext, transformation_ctx)

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'RAW_BUCKET',
    'REFINED_BUCKET',
    'DATABASE_NAME',
    'TABLE_NAME',
])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Default ruleset used by all target nodes with data quality enabled
DEFAULT_DATA_QUALITY_RULESET = """
    Rules = [
        ColumnCount > 0
    ]
"""

raw_bucket = args['RAW_BUCKET']
refined_bucket = args['REFINED_BUCKET']
database_name = args['DATABASE_NAME']
table_name = args['TABLE_NAME']

# Script generated for node Amazon S3
AmazonS3_node1774213896384 = glueContext.create_dynamic_frame.from_options(format_options={}, connection_type="s3", format="parquet", connection_options={"paths": [f"s3://{raw_bucket}/raw/"], "recurse": True}, transformation_ctx="AmazonS3_node1774213896384")

# Script generated for node Aggregate
Aggregate_node1774214037385 = sparkAggregate(glueContext, parentFrame = AmazonS3_node1774213896384, groups = ["ticker", "Date"], aggs = [["Close", "sum"]], transformation_ctx = "Aggregate_node1774214037385")

# Script generated for node rename ticker
renameticker_node1774215245896 = RenameField.apply(frame=Aggregate_node1774214037385, old_name="ticker", new_name="ticker_cod", transformation_ctx="renameticker_node1774215245896")

# Script generated for node rename soma
renamesoma_node1774215699197 = RenameField.apply(frame=renameticker_node1774215245896, old_name="`sum(Close)`", new_name="close", transformation_ctx="renamesoma_node1774215699197")

# Script generated for node SQL Query
SqlQuery0 = '''
select Date, 
    ticker_cod, 
    close,
    MAX(close) OVER (PARTITION BY ticker_cod) as maxima_historica,
    MIN(close) OVER (PARTITION BY ticker_cod) as minima_historica
    from myDataSource
'''
SQLQuery_node1774217631943 = sparkSqlQuery(glueContext, query = SqlQuery0, mapping = {"myDataSource":renamesoma_node1774215699197}, transformation_ctx = "SQLQuery_node1774217631943")

# Script generated for node Amazon S3
EvaluateDataQuality().process_rows(frame=SQLQuery_node1774217631943, ruleset=DEFAULT_DATA_QUALITY_RULESET, publishing_options={"dataQualityEvaluationContext": "EvaluateDataQuality_node1774213891233", "enableDataQualityResultsPublishing": True}, additional_options={"dataQualityResultsPublishing.strategy": "BEST_EFFORT", "observations.scope": "ALL"})
AmazonS3_node1774214432117 = glueContext.getSink(path=f"s3://{refined_bucket}/refined/", connection_type="s3", updateBehavior="UPDATE_IN_DATABASE", partitionKeys=["Date", "ticker_cod"], enableUpdateCatalog=True, transformation_ctx="AmazonS3_node1774214432117")
AmazonS3_node1774214432117.setCatalogInfo(catalogDatabase=database_name,catalogTableName=table_name)
AmazonS3_node1774214432117.setFormat("glueparquet", compression="snappy")
AmazonS3_node1774214432117.writeFrame(SQLQuery_node1774217631943)
job.commit()