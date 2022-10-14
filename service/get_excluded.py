import mysql.connector
from mysql.connector import Error
import subprocess
import json
import botocore 
import botocore.session 
from aws_secretsmanager_caching import SecretCache, SecretCacheConfig 

def main():
    client = botocore.session.get_session().create_client('secretsmanager', region_name='us-east-1')
    cache_config = SecretCacheConfig()
    cache = SecretCache( config = cache_config, client = client)

    secret_value = json.loads(cache.get_secret_string('serviceDBcred'))

    try:
        bashCommand = """/opt/slurm/bin/scontrol show config | grep ClusterName | awk '{print $3}'"""
        process = subprocess.Popen(bashCommand, shell=True, stdout=subprocess.PIPE)
        cluster, error = process.communicate()

        connection = mysql.connector.connect(host=secret_value["host"],
                                            database="service",
                                            user=secret_value["username"],
                                            password=secret_value["password"])
        if connection.is_connected():
            db_Info = connection.get_server_info()
            #print("Connected to MySQL Server version ", db_Info)
            cursor = connection.cursor()
            cursor.execute("select database();")
            record = cursor.fetchone()
            #print("You're connected to database: ", record)
            query = f"select distinct hostname from health where defect = 1 and cluster = '{cluster.decode().strip()}' order by hostname asc;"
            cursor.execute(query)
            records = cursor.fetchall()
            base = ""
            ids = []
            for row in records:
                host = row[0].rsplit('-', 1)
                if (base == ""):
                    base = host[0]
                elif (base != host[0]):
                    break
                ids.append(host[1])
            print(base + "-[" + ",".join(ids) + "]")

    except Error as e:
        print("Error while connecting to MySQL", e)
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()
            #print("MySQL connection is closed")


if __name__ == '__main__':
    main()

# place this file in /opt/slurm/sbin