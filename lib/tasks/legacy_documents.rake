namespace :legacy_documents do
  desc "Decrypt one uploaded NDA for review: legacy_documents:download[import_id,path]"
  task :download, %i[import_id path] => :environment do |_task, arguments|
    import = LegacyNdaImport.find(arguments.fetch(:import_id))
    abort "Import #{import.id} has no upload." unless import.document.attached?

    blob = import.document.blob
    path = arguments[:path] || Rails.root.join("tmp", blob.filename.sanitized).to_s
    File.binwrite(path, SseCustomerBlob.download(blob))
    puts "Wrote a decrypted NDA to #{path}. It contains personal data; delete it when you are done."
  end
end
