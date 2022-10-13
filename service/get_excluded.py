import mysql.connector
from mysql.connector import Error
import json
import botocore 
import botocore.session 
from aws_secretsmanager_caching import SecretCache, SecretCacheConfig 

def main():
    client = botocore.session.get_session().create_client('secretsmanager')
    cache_config = SecretCacheConfig()
    cache = SecretCache( config = cache_config, client = client)

    secret_value = json.loads(cache.get_secret_string('serviceDBcred'))

    try:
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
#----------------------------------------------
#TODO: find current cluster name, replace the parallelcluster-test placeholder with that
#----------------------------------------------
            query = "select distinct hostname from health where defect = 1 and cluster = 'parallelcluster-test' order by hostname asc;"
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