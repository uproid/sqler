# Makefile for Sqler project
# MySQL Docker container management

# MySQL configuration
MYSQL_CONTAINER_NAME = sqler-mysql
MYSQL_ROOT_PASSWORD = root
MYSQL_DATABASE = test
MYSQL_USER = test
MYSQL_PASSWORD = test
MYSQL_PORT = 3306

# Docker image
MYSQL_IMAGE = mysql:8.0

.PHONY: mysql-start mysql-stop mysql-restart mysql-logs mysql-shell mysql-status mysql-clean help

mysql-start: ## Start MySQL Docker container
	@echo "Starting MySQL container..."
	@docker run -d \
		--name $(MYSQL_CONTAINER_NAME) \
		-e MYSQL_ROOT_PASSWORD=$(MYSQL_ROOT_PASSWORD) \
		-e MYSQL_DATABASE=$(MYSQL_DATABASE) \
		-e MYSQL_USER=$(MYSQL_USER) \
		-e MYSQL_PASSWORD=$(MYSQL_PASSWORD) \
		-p $(MYSQL_PORT):3306 \
		$(MYSQL_IMAGE)
	@echo "MySQL container started. Waiting for it to be ready..."
	@sleep 10
	@echo "MySQL is ready at localhost:$(MYSQL_PORT)"
	@echo "Database: $(MYSQL_DATABASE)"
	@echo "Username: $(MYSQL_USER)"
	@echo "Password: $(MYSQL_PASSWORD)"

