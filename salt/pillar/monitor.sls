monitor:
    prometheus:

        # HTTP basic credentials for prometheus web interface.
        # todo: stick behind nginx just like everything else.
        web:
            username: admin
            # dummy password. it's just 'admin' hashed with brypt. 
            password: "$2b$12$14ab29qml2YgqM3U.Bxy/OSbI1ON5GupEbcUVDm59WjnZ8t88hiK6"

        # query AWS for EC2 instances with node_exporter to poll
        ec2_sd_configs:
            access_key: AKIAFOOBAR
            secret_key: asdfasdfasdf
