CREATE OR REPLACE PROCEDURE RecordGPUhealth(
    IN in_gpusn            VARCHAR(50),
    IN in_cluster          VARCHAR(50),
    IN in_hostname         VARCHAR(30),
    IN in_gpuno            INT,
    IN in_instanceid       varchar(30),
    IN in_ipaddr           VARCHAR(15), 
    IN in_defect           INT
)
BEGIN
    INSERT INTO health
        (gpusn, cluster, hostname, gpuno, instanceid, ipaddr, defect)
    VALUES
        (in_gpusn, in_cluster, in_hostname, in_gpuno, in_instanceid, in_ipaddr, in_defect)
    ON DUPLICATE KEY UPDATE
        cluster = in_cluster, hostname = in_hostname, gpuno = in_gpuno, instanceid = in_instanceid, ipaddr = in_ipaddr, defect = in_defect;
    
    INSERT INTO healthlog
        (gpusn, cluster, hostname, gpuno, instanceid, ipaddr, defect)
    VALUES
        (in_gpusn, in_cluster, in_hostname, in_gpuno, in_instanceid, in_ipaddr, in_defect);
END