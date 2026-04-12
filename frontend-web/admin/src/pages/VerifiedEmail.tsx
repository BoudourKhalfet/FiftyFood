import { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";

export default function VerifiedEmail() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [status, setStatus] = useState<"loading" | "success" | "error">("loading");
  const [errorMessage, setErrorMessage] = useState("");

  useEffect(() => {
    const verifyEmail = async () => {
      const token = searchParams.get("token");

      if (!token) {
        setStatus("error");
        setErrorMessage("No verification token found.");
        setTimeout(() => navigate("/"), 3000);
        return;
      }

      try {
        const backendUrl = import.meta.env.VITE_BACKEND_URL || "http://192.168.43.154:3000";
        const response = await fetch(`${backendUrl}/auth/verify-email?token=${token}`);

        if (response.ok) {
          setStatus("success");
          // Redirect after 3 seconds
          setTimeout(() => navigate("/admin/login"), 3000);
        } else {
          const error = await response.json();
          setStatus("error");
          setErrorMessage(error.message || "Email verification failed. Please try again.");
          setTimeout(() => navigate("/"), 3000);
        }
      } catch (err) {
        setStatus("error");
        setErrorMessage("An error occurred while verifying your email. Please try again.");
        setTimeout(() => navigate("/"), 3000);
      }
    };

    verifyEmail();
  }, [searchParams, navigate]);

  if (status === "loading") {
    return (
      <div className="flex items-center justify-center h-screen bg-gradient-to-br from-green-50 to-teal-50">
        <div className="text-center">
          <div className="w-16 h-16 mx-auto mb-4 border-4 border-green-200 border-t-green-600 rounded-full animate-spin"></div>
          <h2 className="text-2xl font-bold text-gray-800">Verifying your email...</h2>
          <p className="text-gray-600 mt-2">Please wait a moment.</p>
        </div>
      </div>
    );
  }

  if (status === "success") {
    return (
      <div className="flex items-center justify-center h-screen bg-gradient-to-br from-green-50 to-teal-50">
        <div className="text-center">
          <div className="w-20 h-20 mx-auto mb-4 bg-green-100 rounded-full flex items-center justify-center">
            <svg className="w-10 h-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h2 className="text-3xl font-bold text-gray-800">Email Verified!</h2>
          <p className="text-gray-600 mt-2">Your email has been successfully verified.</p>
          <p className="text-gray-500 text-sm mt-4">Redirecting you to login...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center h-screen bg-gradient-to-br from-red-50 to-orange-50">
      <div className="text-center">
        <div className="w-20 h-20 mx-auto mb-4 bg-red-100 rounded-full flex items-center justify-center">
          <svg className="w-10 h-10 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </div>
        <h2 className="text-3xl font-bold text-gray-800">Verification Failed</h2>
        <p className="text-gray-600 mt-2">{errorMessage}</p>
        <p className="text-gray-500 text-sm mt-4">Redirecting...</p>
      </div>
    </div>
  );
}
