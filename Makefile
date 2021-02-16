build:
	docker build --build-arg project_id=massive-seer-267723 --tag gcloudrigapi .

run_bash:
	docker run -p 5000:5000 --env PORT=5000 --env JWT_SECRET=testing1234 --env API_USERNAME=test --env API_PASSWORD=password123 -it gcloudrigapi bash

run:
	docker run -p 5000:5000 --env PORT=5000 --env JWT_SECRET=testing1234 --env API_USERNAME=test --env API_PASSWORD=password123 -it gcloudrigapi

stop:
	docker stop $(shell docker ps -q --filter ancestor=gcloudrigapi)