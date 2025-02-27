web: bin/rails server -p ${PORT:-5000} -e production
release: bin/rails db:execute_sql[\"CREATE SCHEMA IF NOT EXISTS cache; CREATE SCHEMA IF NOT EXISTS queue; CREATE SCHEMA IF NOT EXISTS cable;\"] && bin/rails db:migrate
worker: bin/rails solid_queue:start
