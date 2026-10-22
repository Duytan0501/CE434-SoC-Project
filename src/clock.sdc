# 1. Khai báo đơn vị đo lường (Mặc định của GPDK 45nm)
#set_units -time ns -capacitance pF

# 2. Khai báo xung nhịp chính (Clock Definition)
# Chu kỳ 20ns, Duty cycle 50% (Mức cao từ 0 đến 10ns)
create_clock -name PCLK -period 20.000 -waveform {0.000 10.000} [get_ports PCLK]

# 3. Mô hình hóa mạng cây xung nhịp (Clock Tree Modeling)
# Khai báo sai số (Uncertainty) để ép tool trừ hao khi tính toán Setup/Hold. 
# Giúp quá trình CTS (Clock Tree Synthesis) trong Innovus có thêm không gian an toàn.
#set_clock_uncertainty -setup 0.2 [get_clocks PCLK]
#set_clock_uncertainty -hold  0.05 [get_clocks PCLK]

# Khai báo độ dốc sườn xung nhịp (Transition/Slew)
#set_clock_transition 0.1 [get_clocks PCLK]

# 4. Ràng buộc thời gian cho ngõ vào (Input Delays)
# Phân bổ 20% chu kỳ (4.0 ns) cho các khối đứng trước (Interconnect) đi dây đến lõi của bạn.
# Lõi của bạn sẽ còn lại 16.0 ns để tính toán logic bên trong.
#set apb_inputs [list PADDR PSEL PENABLE PWRITE PWDATA PSTRB]
#set_input_delay 4.0 -clock PCLK [get_ports $apb_inputs]

# Tín hiệu Reset thường được lái từ một bộ Synchronizer của hệ thống SoC
#set_input_delay 2.0 -clock PCLK [get_ports PRESETn]

# 5. Ràng buộc thời gian cho ngõ ra (Output Delays)
# Ép ngõ ra của bạn phải chuẩn bị sẵn sàng dữ liệu trước 4.0 ns so với cạnh clock tiếp theo 
# để SoC Interconnect kịp lấy dữ liệu.
#set apb_outputs [list PRDATA PREADY PSLVERR]
#set_output_delay 4.0 -clock PCLK [get_ports $apb_outputs]

# 6. Mô hình hóa môi trường vật lý (Environmental Attributes)
# Giả lập độ dốc của tín hiệu đầu vào (Slew rate) từ các cell logic bên ngoài
#set_input_transition 0.2 [all_inputs]

# Giả lập tải điện dung ở ngõ ra (Output Load)
# Giả sử ngõ ra của Wrapper phải lái một đoạn dây Interconnect tương đương 4-5 cổng tiêu chuẩn.
#set_load 0.05 [all_outputs]

# 7. Khai báo các đường không cần check timing (False Paths)
# Mạch của bạn chỉ có 1 miền xung nhịp (PCLK) nên không có giao tiếp CDC (Clock Domain Crossing).
# Tuy nhiên, ta có thể bỏ qua timing cho tín hiệu lỗi PSLVERR vì nó luôn được gán bằng 0.
#set_false_path -from [get_ports PSLVERR]