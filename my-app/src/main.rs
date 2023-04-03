cpufeatures::new!(cpuid_aes_sha, "aes", "sha");

fn main() {
    let token: cpuid_aes_sha::InitToken = cpuid_aes_sha::init();

    if token.get() {
        println!("CPU supports both SHA and AES extensions");
    } else {
        println!("SHA and AES extensions are not supported");
    }

    println!("Hello, world!");
}
