ekv_dir = Application.get_env(:durable_counter, :ekv_data_dir)

if ekv_dir do
  File.rm_rf!(ekv_dir)
end

ExUnit.start()
