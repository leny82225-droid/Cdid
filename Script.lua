-- =================================================================
-- CONFIG & METADATA
-- Owner   : bruk×ontop⁸⁷
-- Versi   : 1.0.0
-- Script  : indo glarity rebon
-- =================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- State Switch
local AutoJobEnabled = false
local FlySpeed = 100 -- Kecepatan terbang mobil (bisa disesuaikan)

-- =================================================================
-- 1. PROTEKSI & ANTI-DETEKSI
-- =================================================================

-- Anti-AFK (Mencegah kick 20 menit idle)
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

-- Anti-Detection (Bypass Hooking & Metatable Guard)
local setidentity = setidentity or set_thread_identity or setthreadidentity
if setidentity then setidentity(7) end

local gmt = getrawmetatable(game)
local oldNamecall = gmt.__namecall
setreadonly(gmt, false)

gmt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if not checkcaller() and (method == "Kick" or method == "kick") then
        return nil -- Blokir script lokal game yang mencoba Kick player
    end
    return oldNamecall(self, ...)
end)
setreadonly(gmt, true)

-- =================================================================
-- 2. HELPER & UTILITY FUNCTIONS
-- =================================================================

-- Memeriksa apakah player sedang berada di dalam mobil
local function GetPlayerVehicle()
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        local seat = char.Humanoid.SeatPart
        if seat and seat:IsA("VehicleSeat") then
            return seat.Parent -- Mengembalikan model kendaraan
        end
    end
    return nil
end

-- Deteksi lokasi Tanda Panah Kuning (Waypoint CDID)
local function GetYellowArrowPosition()
    -- Mencari titik panah kuning / destination marker di Workspace
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("BillboardGui") then
            local name = obj.Name:lower()
            if name:find("arrow") or name:find("waypoint") or name:find("checkpoint") or name:find("target") or name:find("destination") then
                if obj:IsA("BasePart") then
                    return obj.Position
                elseif obj:IsA("BillboardGui") and obj.Adornee then
                    return obj.Adornee.Position
                end
            end
        end
    end
    return nil
end

-- Fungsi Terbang Halus Mobil Ke Titik Koordinat
local function FlyVehicleTo(targetPos)
    local vehicle = GetPlayerVehicle()
    if not vehicle then return false end

    local primaryPart = vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then return false end

    -- Menghilangkan Efek Gravitasi sementara
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = primaryPart

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.CFrame = primaryPart.CFrame
    bg.Parent = primaryPart

    -- Tween pergerakan agar halus (mencegah rollback anti-cheat)
    local distance = (primaryPart.Position - targetPos).Magnitude
    local tweenInfo = TweenInfo.new(distance / FlySpeed, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(primaryPart, tweenInfo, {CFrame = CFrame.new(targetPos)})

    tween:Play()
    tween.Completed:Wait()

    bv:Destroy()
    bg:Destroy()
    return true
end

-- =================================================================
-- 3. LOGIKA UTAMA AUTO JOB
-- =================================================================

task.spawn(function()
    while task.wait(0.5) do
        if AutoJobEnabled then
            Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
            
            local vehicle = GetPlayerVehicle()

            -- LOGIKA 1: JIKA MOBIL HILANG / BELUM ADA MOBIL
            if not vehicle then
                -- 1. Jalan/Teleport ke Lokasi Tulisan 'JOB'
                local jobMarker = Workspace:FindFirstChild("Job", true) or Workspace:FindFirstChild("TakeJob", true)
                if jobMarker and jobMarker:IsA("BasePart") then
                    HumanoidRootPart.CFrame = jobMarker.CFrame + Vector3.new(0, 3, 0)
                    task.wait(1.5)
                end

                -- 2. Ambil Job Otomatis (Proses Interaction/Prompt)
                local proximity = Workspace:FindFirstChildWhichIsA("ProximityPrompt", true)
                if proximity then
                    fireproximityprompt(proximity)
                    task.wait(1)
                end

                -- 3. Naik/Mendekat ke Mobil yang Baru Muncul
                local myVehicle = Workspace:FindFirstChild(LocalPlayer.Name .. "'s Vehicle") or Workspace:FindFirstChild("Vehicles")
                if myVehicle then
                    local seat = myVehicle:FindFirstChildWhichIsA("VehicleSeat", true)
                    if seat then
                        HumanoidRootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
                        task.wait(2)
                    end
                end

            -- LOGIKA 2: JIKA SUDAH DI DALAM MOBIL
            else
                local targetPos = GetYellowArrowPosition()
                if targetPos then
                    -- A. Mobil Terbang Mengikuti Panah Kuning (Melayang Sedikit di Atas Jalan)
                    FlyVehicleTo(targetPos + Vector3.new(0, 10, 0))
                    
                    -- B. Pas di Dekat Titik, Mobil Turun
                    FlyVehicleTo(targetPos + Vector3.new(0, 2, 0))
                    
                    -- C. Menunggu Sistem Mengirim / Menerima Job & Uang Masuk
                    task.wait(3)
                end
            end
        end
    end
end)

-- =================================================================
-- 4. GUI MENGAMBANG (FLOATING MENU)
-- =================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "IndoGlarityRebonCDID"
ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer.PlayerGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 230, 0, 190)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

-- Header Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 32)
Title.Text = "indo glarity rebon"
Title.TextColor3 = Color3.fromRGB(255, 215, 0)
Title.TextSize = 14
Title.Font = Enum.Font.SourceSansBold
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = Title

-- Info Owner & Versi
local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(1, -10, 0, 40)
Info.Position = UDim2.new(0, 5, 0, 35)
Info.Text = "Owner: bruk×ontop⁸⁷\nVersi: 1.0.0"
Info.TextColor3 = Color3.fromRGB(180, 180, 180)
Info.TextSize = 12
Info.Font = Enum.Font.SourceSans
Info.BackgroundTransparency = 1
Info.Parent = MainFrame

-- Button Toggle Auto Job
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0.9, 0, 0, 35)
ToggleBtn.Position = UDim2.new(0.05, 0, 0, 80)
ToggleBtn.Text = "AUTO JOB CDID: OFF"
ToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.TextSize = 12
ToggleBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = ToggleBtn

ToggleBtn.MouseButton1Click:Connect(function()
    AutoJobEnabled = not AutoJobEnabled
    if AutoJobEnabled then
        ToggleBtn.Text = "AUTO JOB CDID: ON"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
    else
        ToggleBtn.Text = "AUTO JOB CDID: OFF"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    end
end)

-- Status Info
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -10, 0, 30)
Status.Position = UDim2.new(0, 5, 0, 125)
Status.Text = "[✓] Anti-AFK Active\n[✓] Anti-Bypass Loaded"
Status.TextColor3 = Color3.fromRGB(0, 255, 120)
Status.TextSize = 11
Status.Font = Enum.Font.SourceSansItalic
Status.BackgroundTransparency = 1
Status.Parent = MainFrame

