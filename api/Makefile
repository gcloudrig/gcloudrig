build:
	docker build --tag gcloudrigapi .

run:
	docker run -p 5000:5000 -it --env PORT=5000 --env JWT_SECRET=testing1234 --env USERNAME=test --env PASSWORD=password123 gcloudrigapi

stop:
	docker stop $(shell docker ps -q --filter ancestor=gcloudrigapi)