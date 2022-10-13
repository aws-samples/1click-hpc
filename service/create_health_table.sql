CREATE TABLE health(
    gpusn VARCHAR(50) NOT NULL,
    cluster VARCHAR(50) NOT NULL,
    hostname VARCHAR(30) NOT NULL,
    gpuno INT NOT NULL,
    instanceid varchar(30) NOT NULL,
    ipaddr VARCHAR(15) NOT NULL,
    defect BIT,
    lastlogged timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY(gpusn)
);

CREATE TABLE healthlog(
    gpusn VARCHAR(50) NOT NULL,
    cluster VARCHAR(50) NOT NULL,
    hostname VARCHAR(30) NOT NULL,
    gpuno INT NOT NULL,
    instanceid varchar(30) NOT NULL,
    ipaddr VARCHAR(15) NOT NULL,
    defect BIT,
    lastlogged timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);
