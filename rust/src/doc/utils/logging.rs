use log;

// Define a macro for combined println and info logging
#[macro_export]
macro_rules! log_info {
    ($($arg:tt)*) => {
        {
        let message = format!($($arg)*);
        log::info!("{}", message);
        println!("{}", message);
        }
    };
}

// Define a macro for combined println and error logging
#[macro_export]
macro_rules! log_error {
    ($($arg:tt)*) => {
        {
        let message = format!($($arg)*);
        log::error!("{}", message);
        println!("{}", message);
        }
    };
}