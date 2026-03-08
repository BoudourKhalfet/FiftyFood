import React, { useState } from "react";
import {
  Box,
  Button,
  Card,
  CardContent,
  TextField,
  Typography,
  InputAdornment,
  IconButton,
  Link,
} from "@mui/material";
import EmailOutlinedIcon from "@mui/icons-material/EmailOutlined";
import LockOutlinedIcon from "@mui/icons-material/LockOutlined";
import Visibility from "@mui/icons-material/Visibility";
import VisibilityOff from "@mui/icons-material/VisibilityOff";

// Replace with your logo path
import logo from "../assets/logo.png";

const AdminLogin: React.FC = () => {
  const [email, setEmail] = useState("");
  const [pw, setPw] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handlePwVisibility = () => setShowPw(!showPw);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const resp = await fetch("/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password: pw }),
      });
      const data = await resp.json();
      if (resp.ok && data.accessToken) {
        localStorage.setItem("access_token", data.accessToken);
        window.location.href = "/admin";
      } else {
        setError(data.message || "Login failed!");
      }
    } catch {
      setError("Network error!");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Box
      sx={{
        background: "#fafafa",
        minHeight: "100vh",
        display: "flex",
        alignItems: "flex-start",
        justifyContent: "center",
        pt: 13,
      }}
    >
      <Box sx={{ width: 390 }}>
        <Box
          sx={{
            mb: 2,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            textAlign: "center",
          }}
        >
          <img
            src={logo}
            alt="FiftyFood logo"
            style={{
              width: 230,
              height: 80,
              textAlign: "center",
            }}
            onError={(e) => (e.currentTarget.style.display = "none")}
          />
        </Box>
        <Typography
          variant="h4"
          fontWeight={700}
          textAlign={"center"}
          mb={1}
          color="#222"
        >
          Welcome back
        </Typography>
        <Typography
          variant="subtitle1"
          sx={{ color: "#818181", fontWeight: 400, textAlign: "center", mb: 2 }}
        >
          Sign in to access your admin dashboard
        </Typography>
        <Card elevation={0} sx={{ borderRadius: 3, p: 2 }}>
          <CardContent>
            <form onSubmit={handleSubmit}>
              <TextField
                margin="normal"
                placeholder="Email"
                variant="outlined"
                fullWidth
                size="medium"
                autoFocus
                autoComplete="username"
                value={email}
                onChange={(e: {
                  target: { value: React.SetStateAction<string> };
                }) => setEmail(e.target.value)}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <EmailOutlinedIcon sx={{ color: "#6B7280" }} />
                    </InputAdornment>
                  ),
                }}
                required
              />
              <TextField
                margin="normal"
                placeholder="Password"
                variant="outlined"
                fullWidth
                size="medium"
                type={showPw ? "text" : "password"}
                autoComplete="current-password"
                value={pw}
                onChange={(e: {
                  target: { value: React.SetStateAction<string> };
                }) => setPw(e.target.value)}
                required
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <LockOutlinedIcon sx={{ color: "#6B7280" }} />
                    </InputAdornment>
                  ),
                  endAdornment: (
                    <InputAdornment position="end">
                      <IconButton
                        onClick={handlePwVisibility}
                        edge="end"
                        size="small"
                      >
                        {showPw ? <VisibilityOff /> : <Visibility />}
                      </IconButton>
                    </InputAdornment>
                  ),
                }}
              />
              <Box display="flex" justifyContent="flex-end" mb={2} mt={-1}>
                <Link
                  href="/reset-password"
                  underline="hover"
                  fontSize={15}
                  color="#17987C"
                  sx={{ fontWeight: 500 }}
                >
                  Forgot password?
                </Link>
              </Box>
              {error && (
                <Typography color="error" sx={{ mb: 2 }}>
                  {error}
                </Typography>
              )}
              <Button
                variant="contained"
                color="success"
                fullWidth
                size="large"
                sx={{
                  background: "#17987C",
                  borderRadius: "9px",
                  fontWeight: 600,
                  fontSize: "18px",
                  py: 1.2,
                  mt: 1,
                  mb: 1,
                  letterSpacing: 0.4,
                  textTransform: "none",
                  "&:hover": { background: "#13775e" },
                  boxShadow: "none",
                }}
                type="submit"
                disabled={loading}
                endIcon={<span style={{ fontSize: 22 }}>→</span>}
              >
                Sign In
              </Button>
            </form>
          </CardContent>
        </Card>
      </Box>
    </Box>
  );
};

export default AdminLogin;
