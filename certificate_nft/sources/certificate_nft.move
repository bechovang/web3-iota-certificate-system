module certificate_nft::verimove {
    use std::string::{Self, String};
    use iota::event;
    use iota::clock::{Self, Clock};
    
    // --- MÃ LỖI ---
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_VERIFIED: u64 = 2;
    const E_ALREADY_REVOKED: u64 = 3;

    // --- STRUCTS ---

    /// 0. ADMIN CAP (Quyền lực tối cao của hệ thống VeriMove)
    /// Chỉ có ví người Deploy (Bạn) mới giữ cái này.
    /// Dùng để tích xanh (Verify) cho các Tổ chức.
    public struct VeriMoveAdminCap has key, store {
        id: UID,
    }

    /// 1. PROFILE TỔ CHỨC (Organization)
    public struct Organization has key, store {
        id: UID,
        name: String,        // Tên tổ chức (VD: Google, FPT)
        industry: String,    // Ngành nghề
        image_url: String,   // Logo
        admin_addr: address, // Ví admin của công ty
        is_verified: bool,   // TRẠNG THÁI KYC (True = Có tích xanh)
    }

    /// 2. ORG CAP (Con dấu của Tổ chức)
    public struct OrgCap has key, store {
        id: UID,
        org_id: ID, 
    }

    /// 3. CAREER ITEM (Mục CV - Soulbound)
    public struct CareerItem has key {
        id: UID,
        // -- Thông tin --
        holder_name: String,     
        title: String,           
        org_name: String,        
        category: String,        
        start_date: String,      
        end_date: String,        
        description: String,     
        
        // -- Dữ liệu xác thực --
        issue_date: u64,         
        issuer_id: ID,           
        status: u8,              // 0: Active (Hiệu lực), 1: Revoked (Đã thu hồi)
    }

    // --- EVENTS ---
    
    // Sự kiện khi Tổ chức đăng ký
    public struct OrgRegistered has copy, drop {
        org_id: ID,
        name: String,
    }

    // Sự kiện khi Admin Verify tổ chức (KYC thành công)
    public struct OrgVerified has copy, drop {
        org_id: ID,
    }

    // Sự kiện khi cấp bằng
    public struct ItemIssued has copy, drop {
        id: ID,
        holder: address,
        org_name: String,
        title: String,
        org_verified: bool, // Frontend dựa vào đây hiện Badge xanh ngay lập tức
    }

    // Sự kiện khi thu hồi bằng
    public struct ItemRevoked has copy, drop {
        id: ID,
        reason: String,
    }

    // --- FUNCTIONS ---

    /// Init: Khởi tạo AdminCap cho người deploy contract
    fun init(ctx: &mut TxContext) {
        let admin_cap = VeriMoveAdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    // --- CÁC HÀM CHO TỔ CHỨC ---

    /// BƯỚC 1: Tổ chức đăng ký (Mặc định chưa verify)
    public entry fun register_organization(
        name: vector<u8>,
        industry: vector<u8>,
        image_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let uid = object::new(ctx);
        let org_id = object::uid_to_inner(&uid);

        let org = Organization {
            id: uid,
            name: string::utf8(name),
            industry: string::utf8(industry),
            image_url: string::utf8(image_url),
            admin_addr: sender,
            is_verified: false, // Mặc định là FALSE (Chưa có tích xanh)
        };

        let cap = OrgCap {
            id: object::new(ctx),
            org_id,
        };

        event::emit(OrgRegistered {
            org_id,
            name: org.name,
        });

        transfer::share_object(org); 
        transfer::transfer(cap, sender); 
    }

    /// BƯỚC 2: Cấp bằng/Xác nhận kinh nghiệm
    public entry fun issue_career_item(
        org: &Organization,       
        _cap: &OrgCap,            
        clock: &Clock,            
        holder_name: vector<u8>,
        title: vector<u8>,        
        category: vector<u8>,     
        start_date: vector<u8>,   
        end_date: vector<u8>,     
        description: vector<u8>,  
        recipient: address,       
        ctx: &mut TxContext
    ) {
        // Chỉ admin công ty mới được cấp
        assert!(org.admin_addr == tx_context::sender(ctx), E_NOT_AUTHORIZED);

        let current_time = clock::timestamp_ms(clock);
        let org_name_str = org.name;
        
        let item = CareerItem {
            id: object::new(ctx),
            holder_name: string::utf8(holder_name),
            title: string::utf8(title),
            org_name: org_name_str,
            category: string::utf8(category),
            start_date: string::utf8(start_date),
            end_date: string::utf8(end_date),
            description: string::utf8(description),
            issue_date: current_time,
            issuer_id: object::uid_to_inner(&org.id),
            status: 0, // 0 = Active
        };

        event::emit(ItemIssued {
            id: object::uid_to_inner(&item.id),
            holder: recipient,
            org_name: org_name_str,
            title: item.title,
            org_verified: org.is_verified, // Bắn trạng thái verify ra event
        });

        transfer::transfer(item, recipient);
    }

    /// BƯỚC 3: Thu hồi bằng (Khi nhân viên bị sa thải hoặc bằng cấp sai)
    public entry fun revoke_career_item(
        _cap: &OrgCap,           // Phải có con dấu
        item: &mut CareerItem,   // Object bằng cấp cần sửa
        reason: vector<u8>,
        _ctx: &mut TxContext
    ) {
        // Kiểm tra xem con dấu có khớp với nơi cấp bằng không
        // (Tránh việc công ty A đi thu hồi bằng của công ty B)
        assert!(_cap.org_id == item.issuer_id, E_NOT_AUTHORIZED);
        assert!(item.status == 0, E_ALREADY_REVOKED);

        item.status = 1; // 1 = Revoked

        event::emit(ItemRevoked {
            id: object::uid_to_inner(&item.id),
            reason: string::utf8(reason),
        });
    }

    // --- CÁC HÀM CHO ADMIN HỆ THỐNG (BẠN) ---

    /// KYC: Xác thực tổ chức (Cấp tích xanh)
    public entry fun verify_organization(
        _admin: &VeriMoveAdminCap, // Phải có quyền Admin hệ thống
        org: &mut Organization,    // Object tổ chức cần verify
        _ctx: &mut TxContext
    ) {
        org.is_verified = true;

        event::emit(OrgVerified {
            org_id: object::uid_to_inner(&org.id),
        });
    }
}