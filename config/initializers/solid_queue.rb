if Rails.env.production?
  # Set table names individually for SolidQueue models
  SolidQueue::Job.table_name = "queue.jobs"
  SolidQueue::Process.table_name = "queue.processes"
  SolidQueue::Ready.table_name = "queue.readies"
  SolidQueue::Scheduled.table_name = "queue.scheduleds"
  SolidQueue::Semaphore.table_name = "queue.semaphores"
  SolidQueue::Claimed.table_name = "queue.claimeds"
  SolidQueue::Failed.table_name = "queue.faileds"
  SolidQueue::Blocked.table_name = "queue.blockeds"
  SolidQueue::Pause.table_name = "queue.pauses"
end
