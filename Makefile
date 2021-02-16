build:
	docker build --tag gcloudrigapi .

run:
	docker run -p 5000:5000 --env PORT=5000 --env JWT_SECRET=testing1234 --env API_USERNAME=test --env API_PASSWORD=password123 --env GOOGLE_APPLICATION_CREDENTIALS=./service_account.json -it gcloudrigapi bash

stop:
	docker stop $(shell docker ps -q --filter ancestor=gcloudrigapi)