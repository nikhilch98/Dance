package request

import (
	"encoding/json"
	"io"
	"nachna/core"
)

type SendOTPRequest struct {
	MobileNumber string `json:"mobile_number"`
}

func (r *SendOTPRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if r.MobileNumber == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "mobile_number is required",
		}
	}

	return nil
}

type VerifyOTPRequest struct {
	MobileNumber string `json:"mobile_number"`
	OTP          string `json:"otp"`
}

func (r *VerifyOTPRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if r.MobileNumber == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "mobile_number is required",
		}
	}

	if r.OTP == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "otp is required",
		}
	}

	return nil
}

type ProfileUpdateRequest struct {
	Name        *string `json:"name,omitempty"`
	DateOfBirth *string `json:"date_of_birth,omitempty"`
	Gender      *string `json:"gender,omitempty"`
}

func (r *ProfileUpdateRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	return nil
}

type DeviceTokenRequest struct {
	DeviceToken string `json:"device_token"`
	Platform    string `json:"platform"`
}

func (r *DeviceTokenRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if r.DeviceToken == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "device_token is required",
		}
	}

	if r.Platform == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "platform is required",
		}
	}

	return nil
}
