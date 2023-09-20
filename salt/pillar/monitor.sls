monitor:
    prometheus:

        # HTTP basic credentials for prometheus web interface.
        web:
            username: admin
            password: admin
            password_hashed: "$2b$12$14ab29qml2YgqM3U.Bxy/OSbI1ON5GupEbcUVDm59WjnZ8t88hiK6" # "admin" hashed

        # query AWS for EC2 instances with node_exporter to poll
        ec2_sd_configs:
            access_key: AKIAFOOBAR
            secret_key: asdfasdfasdf

    alertmanager:
        smtp: email-smtp.us-east-1.amazonaws.com:587 # SES throttles port 25
        from: no-reply@example.org
        user:
        # this is *not* the AWS secret key for the IAM user but a value derived from it.
        # see: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/smtp-credentials.html
        pass:
        receiver:
            email_to: bar@example.org

    yace:
        aws:
            access_key: AKIAFOOBAR
            secret_key: asdfasdfasdf

    healthcheck_list:
        - label: Foo (Bar) # Prometheus alert name
          name: foo-bar # AWS Route53 health check 'name'
          id: 1234-5678-91011 # AWS Route53 health check ID
          duration: 5m
          description: "Health check for foo has been less than 100% for 1 minute."
