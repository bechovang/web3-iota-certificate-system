module certificate_nft::verimove {
    use std::string::{Self, String};
    use iota::event;
    use iota::clock::{Self, Clock};
    
    // Đã xóa hết các dòng use thừa để không bị warning (IOTA tự có sẵn object, transfer, tx_context)

    // --- CẤU HÌNH ĐIỂM SỐ ---
    const BASE_SCORE: u64 = 50;       // Điểm khởi đầu cho trường uy tín
    const MAX_SCORE: u64 = 100;       // Điểm tối đa
    const SCORE_PER_VERIFY: u64 = 5;  // Cộng 5 điểm mỗi lần verify

    // --- MÃ LỖI (Để debug) ---
    const E_NOT_AUTHORIZED: u64 = 1;  // Lỗi: Không có quyền
    const E_CREDENTIAL_REVOKED: u64 = 2; // Lỗi: Bằng đã bị thu hồi

    // --- STRUCTS (Cấu trúc dữ liệu) ---

    /// 1. ISSUER (Hồ sơ Trường học/Tổ chức)
    /// Object này là Shared Object (Ai cũng xem được thông tin trường)
    public struct Issuer has key, store {
        id: UID,
        name: String,        // Tên trường (VD: FPT University)
        website: String,     // Website
        total_issued: u64,   // Tổng số bằng đã cấp
        admin_addr: address, // Địa chỉ ví Admin của trường
    }

    /// 2. ISSUER CAP (Con dấu quyền lực)
    /// Chỉ Admin giữ cái này mới được quyền gọi hàm cấp bằng.
    public struct IssuerCap has key, store {
        id: UID,
        // FIX: Đổi từ address -> ID để khớp dữ liệu
        issuer_id: ID, // Link tới hồ sơ Issuer ở trên (lưu Object ID)
    }

    /// 3. CREDENTIAL (Bằng cấp Soulbound)
    /// QUAN TRỌNG: Chỉ có 'key', KHÔNG CÓ 'store' => Không thể bán/chuyển nhượng.
    public struct Credential has key {
        id: UID,
        holder_name: String,     // Tên sinh viên
        credential_type: String, // Loại bằng
        issue_date: u64,         // Ngày cấp (Timestamp)
        issuer_name: String,     // Tên trường cấp
        
        // --- DYNAMIC FIELDS (Dữ liệu động) ---
        trust_score: u64,        // Điểm tin cậy (Thay đổi được)
        verification_count: u64, // Số lần verify (Thay đổi được)
        last_verified_at: u64,   // Thời gian verify gần nhất
        status: u8,              // 0: Active, 1: Revoked
    }

    // --- EVENTS (Bắn tín hiệu ra ngoài cho Web bắt) ---
    public struct CredentialMinted has copy, drop {
        // FIX: Đổi từ address -> ID để khớp với object::uid_to_inner()
        id: ID,        // Object ID của credential vừa mint
        holder: address, // Địa chỉ ví của người nhận bằng
    }

    public struct CredentialVerified has copy, drop {
        // FIX: Đổi từ address -> ID để khớp với object::uid_to_inner()
        id: ID,        // Object ID của credential vừa verify
        new_score: u64, // Điểm trust score mới sau khi verify
    }

    // --- FUNCTIONS (Chức năng) ---

    /// Init: Hàm khởi tạo mặc định (có thể để trống)
    fun init(_ctx: &mut TxContext) {}

    /// BƯỚC 1: Đăng ký trường học (Tạo Issuer)
    public entry fun register_issuer(
        name: vector<u8>,
        website: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        // Tạo ID mới
        let uid = object::new(ctx);
        // Lấy ID của object vừa tạo (kiểu ID, không phải address)
        let issuer_id = object::uid_to_inner(&uid);

        // Tạo hồ sơ trường
        let issuer = Issuer {
            id: uid,
            name: string::utf8(name),
            website: string::utf8(website),
            total_issued: 0,
            admin_addr: sender,
        };

        // Tạo con dấu (Cap)
        let issuer_cap = IssuerCap {
            id: object::new(ctx),
            issuer_id, // Bây giờ khớp kiểu ID rồi, không lỗi nữa
        };

        // Share hồ sơ trường cho cộng đồng xem
        transfer::share_object(issuer);
        // Gửi con dấu về ví người đăng ký
        transfer::transfer(issuer_cap, sender);
    }

    /// BƯỚC 2: Cấp bằng (Mint)
    /// Cần: Hồ sơ trường, Con dấu, Clock (thời gian), thông tin sinh viên
    public entry fun issue_credential(
        issuer: &mut Issuer,      // Update số lượng bằng
        _cap: &IssuerCap,         // Check quyền Admin
        clock: &Clock,            // Lấy giờ hệ thống (0x6)
        holder_name: vector<u8>,
        credential_type: vector<u8>,
        recipient: address,       // Ví sinh viên
        ctx: &mut TxContext
    ) {
        // Kiểm tra xem người gọi hàm có phải là admin của trường không
        assert!(issuer.admin_addr == tx_context::sender(ctx), E_NOT_AUTHORIZED);

        let current_time = clock::timestamp_ms(clock);
        
        // Tạo bằng mới
        let credential = Credential {
            id: object::new(ctx),
            holder_name: string::utf8(holder_name),
            credential_type: string::utf8(credential_type),
            issue_date: current_time,
            issuer_name: issuer.name,
            
            // Khởi tạo chỉ số Dynamic
            trust_score: BASE_SCORE, // Bắt đầu là 50
            verification_count: 0,
            last_verified_at: 0,
            status: 0, // Active
        };

        // Tăng bộ đếm của trường
        issuer.total_issued = issuer.total_issued + 1;

        // Bắn event
        event::emit(CredentialMinted {
            id: object::uid_to_inner(&credential.id), // Khớp kiểu ID
            holder: recipient,
        });

        // Gửi bằng cho sinh viên
        transfer::transfer(credential, recipient);
    }

    /// BƯỚC 3: Xác minh (Verify) - Tăng điểm Trust Score
    public entry fun verify_credential(
        cred: &mut Credential,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        // Kiểm tra bằng có bị thu hồi không
        assert!(cred.status == 0, E_CREDENTIAL_REVOKED);

        let current_time = clock::timestamp_ms(clock);

        // Logic tăng điểm: Cộng dồn số lần verify
        cred.verification_count = cred.verification_count + 1;
        cred.last_verified_at = current_time;

        // Biến này có 'mut' nên thay đổi được
        let mut new_score = cred.trust_score + SCORE_PER_VERIFY;
        
        // Nếu vượt quá điểm tối đa, giới hạn ở MAX_SCORE
        if (new_score > MAX_SCORE) {
            new_score = MAX_SCORE;
        };
        
        // Gán giá trị mới vào struct
        cred.trust_score = new_score;

        // Bắn event cập nhật điểm
        event::emit(CredentialVerified {
            id: object::uid_to_inner(&cred.id), // Khớp kiểu ID
            new_score: cred.trust_score,
        });
    }
}