/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./resources/**/*.blade.php",
        "./resources/**/**/*.blade.php",
        "./resources/**/**/**/*.blade.php",
    ],
    safelist: [
        // Daftar semua kelas warna yang mungkin dari model Lead
        'bg-gray-500',
        'bg-blue-500',
        'bg-green-500',
        'bg-purple-500',
        'bg-orange-500',
        'bg-emerald-500',
        'bg-red-500',
        'bg-gray-400',
        'bg-blue-400',
        'bg-yellow-500',
        'bg-red-500'
    ],
    theme: {
        extend: {
            colors: {
                red: {
                    700: "RGB(253, 10, 10)", // Red color matching the logo
                },
                black: "#000000",
                neutral: {
                    300: "#d1d5db",
                },
                white: "#ffffff",
                turquoise: "rgb(24, 254, 255)",
                blue: {
                    900: "rgb(9, 10, 252)",
                },
                green: {
                    500: "rgb(102, 253, 10)",
                },
            },
        },
    },
    daisyui: {
        themes: ["light"],
    },
    plugins: [require("daisyui")],
};
