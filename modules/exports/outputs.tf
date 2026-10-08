output "exporter_sa" { value = google_service_account.exporter.email }
output "scheduler_jobs" { value = [for j in google_cloud_scheduler_job.export : j.name] }