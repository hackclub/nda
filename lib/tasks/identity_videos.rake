namespace :identity_videos do
  desc "Run the retention purge now instead of waiting for its daily schedule"
  task purge: :environment do
    purged = PurgeIdentityVideosJob.perform_now
    puts "Purged #{purged} identity video(s) older than #{NdaSignature::IDENTITY_VIDEO_RETENTION.inspect}."
  end

  desc "Decrypt one identity video for review: identity_videos:download[signature_id,path]"
  task :download, %i[signature_id path] => :environment do |_task, arguments|
    signature = NdaSignature.find(arguments.fetch(:signature_id))
    abort "Signature #{signature.id} has no identity video." unless signature.identity_video.attached?

    blob = signature.identity_video.blob
    service = blob.service
    abort "#{service.class} does not use SSE-C; read the file from disk instead." unless
      service.is_a?(ActiveStorage::Service::S3Service)

    object = service.client.client.get_object(
      bucket: service.bucket.name,
      key: blob.key,
      sse_customer_algorithm: "AES256",
      sse_customer_key: ENV.fetch("R2_SSE_CUSTOMER_KEY")
    )
    path = arguments[:path] || Rails.root.join("tmp", blob.filename.sanitized).to_s
    File.binwrite(path, object.body.read)
    puts "Wrote a decrypted identity video to #{path}. Delete it when the review is finished."
  end
end
