web: bin/rails server -p ${PORT:-5000} -e production
release: bin/rails db:migrate
worker: bin/rails solid_queue:start
