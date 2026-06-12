docker-test:
	docker compose up -d
	sleep 5 # Wait for the database to be ready
	dart test


