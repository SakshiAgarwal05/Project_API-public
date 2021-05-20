# Get credentials for S3 upload.
# AWS_SECRET_KEY: s3 secret
# AWS_ACCESS_KEY: s3 access key
class Api::V1:: S3Controller < ApplicationController
  # retrun aws s3 details required to upload a file
  # We will use a different setting for uploading a resume
  # ====URL
  #   /signature_and_policy [GET]
  # ====PARAMETERS
  #   for_resume (true/false)
  def signature_and_policy
    begin
      s3 = Aws::S3::Resource.new
      @bucket = s3.bucket(ENV['BUCKET_NAME'])
      uuid = SecureRandom.uuid
      params[:filename] = params[:filename].gsub(/[^\w\d\.\_\-]/, '-')
      form = @bucket.presigned_post(
        key: "#{uuid}/#{Time.now.to_i}-#{params[:filename]}",
        acl: 'private',
        success_action_status: '201',
        key_starts_with: uuid,
        content_length_range: CSConstants::FILE_UPLOAD[:min]..CSConstants::FILE_UPLOAD[:max],
        content_type: params[:content_type]
      )
      render json: form.fields
        .merge(url: form.url.gsub("s3-#{ENV['AWS_REGION']}", "s3.#{ENV['AWS_REGION']}"),
               full_path: SignedUrl.get(form.url + '/' + form.fields['key']).
                gsub("s3-#{ENV['AWS_REGION']}", "s3.#{ENV['AWS_REGION']}")
            ),
             status: :ok
    rescue
      render json: {error: 'There is some error connecting to server'}, status: :ok
    end
  end

  protected

  def aws_key_var
    ENV['AWS_SECRET_KEY']
  end

  def bucket_name_var
    ENV['BUCKET_NAME']
  end

  def key_id_var
    ENV['AWS_ACCESS_KEY']
  end
end
