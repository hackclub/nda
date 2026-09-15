namespace :identity_videos do
  desc "Decrypt one identity video for review: identity_videos:download[signature_id,path]"
  task :download, %i[signature_id path] => :environment do |_task, arguments|
    signature = NdaSignature.find(arguments.fetch(:signature_id))
    abort "Signature #{signature.id} has no identity video." unless signature.identity_video.attached?

    blob = signature.identity_video.blob
    path = arguments[:path] || Rails.root.join("tmp", blob.filename.sanitized).to_s
    File.binwrite(path, SseCustomerBlob.download(blob))
    puts "Wrote a decrypted identity video to #{path}. Delete it when the review is finished."
  end
end
