--[[
    Oyun Otomasyon Script'i v29.0
    Yapan: Gemini
    Hata Düzeltmeleri: Gemini

    Özellikler:
    - YENİ (v29.0): Sıralama Editörü'ne "Mevcut Unit'leri Ekle" butonu eklendi. Bu buton, sahadaki tüm birimleri tarar ve onların konum/yön bilgileriyle birlikte hem "Place" hem de "Upgrade" görevleri olarak listeye otomatik ekler.
    - YENİ: "Listeyi Güncelle" butonları artık birimlerin temel 15 haneli ID'lerini doğru bir şekilde alıyor ve listenin sonuna ekliyor.
    - YENİ: Editördeki birim ID listesi artık isimler yerine direkt ID'leri gösteriyor ve dinamik olarak güncelleniyor.
    - YENİ: Tüm menü metinleri daha görünür olması için tam beyaza ayarlandı.
    - YENİ: Editöre "Mouse ile Konum Seç" özelliği eklendi.
    - YENİ: Editöre "Son Yerleştirilen ID'yi Kopyala" özelliği eklendi.
    - YENİ: Sıralamalara "Tekrarla" seçeneği eklendi.
    - YENİ: Ana menü artık düzgün bir şekilde kaydırılabilir.
    - DÜZELTME: Script'in açılmasını engelleyen tüm parser hataları ve geçersiz karakterler temizlendi.
]]

--// Ayarlar Bölümü //--

local YERLESTIRME_BEKLEME_SURESI = 1
local YUKSELTME_BEKLEME_SURESI = 0.5
local OYLAMA_ARALIGI = 30

-- Ana döngüde yerleştirilecek birimler (Dinamik olarak güncellenecek)
local YERLESTIRILECEK_BIRIM_SIRALAMASI = {
    "cda8bd1e49cb4e6", "552bb0082e3e430", "0642a925d6ff45f",
    "bba0906d92e5475", "46d7937d81e9492"
}

-- Diğer Özel Alanlar (Sıralama modu aktif değilken çalışır)
local OZEL_ALANLAR = {
    {
        name = "Savunma Noktası 1",
        trigger_pos = vector.create(356.1318054199219, 98.67900848388672, -496.1645202636719),
        trigger_radius = 200, cooldown = 20,
        placements = {
            { id = "5ddd6d5da7d44da", data = { Origin = vector.create(356.1318054199219, 98.67900848388672, -496.1645202636719), Direction = vector.create(-0.15536153316497803, -0.8695107698440552, 0.4688430726528168) } }
        }
    },
    {
        name = "Savunma Noktası 2",
        trigger_pos = vector.create(370.8471984863281, 94.1212387084961, -478.9883117675781),
        trigger_radius = 200, cooldown = 20,
        placements = {
            { id = "5ddd6d5da7d44da", data = { Origin = vector.create(370.8471984863281, 94.1212387084961, -478.9883117675781), Direction = vector.create(-0.6568723917007446, -0.6351681351661682, -0.40630051493644714) } }
        }
    },
    {
        name = "Yeni Savunma Alanı",
        trigger_pos = vector.create(370.80, 26.57, 958.25),
        trigger_radius = 200, cooldown = 20,
        placements = {
            { id = "5ddd6d5da7d44da", data = { Origin = vector.create(387.9231872558594, 62.10683059692383, 932.6566162109375), Direction = vector.create(3.1401143074035645, -45.0462760925293, 21.470279693603516) } },
            { id = "5ddd6d5da7d44da", data = { Origin = vector.create(383.3031921386719, 58.480743408203125, 956.4286499023438), Direction = vector.create(0.3527563214302063, -45.0462760925293, 21.69582176208496) } }
        }
    }
}


--// Script'in Kendisi (Değiştirmenize gerek yok) //--

task.wait(1)

-- Gerekli Servisler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer:WaitForChild("PlayerGui")

local scriptAktif = true
local inSequenceArea = false
local inAnySpecialArea = false
local sequenceEditorOpen = false
local sonucSecimi = "replay"
local sequenceSystemActive = true
local mainAndSpecialActive = true
local lastPlacedUnitId = ""

-- Lobi Otomasyonu Değişkenleri
local lobbyAutomationActive = false
local lobbyNextMode = "Event"
local lobbyAlternativeCode = ""
local lastChallengeSlot = {hour = -1, minute = -1}
local lobbyEntryTime = 0
local challengeAttempts = {}

-- JSON Ayar Kayıt Sistemi
local settings_folder = "Delta"
local sequences_folder = settings_folder .. "/Sequences"
local main_settings_file = settings_folder .. "/auto_placer_main_settings_v28.json"

local function bildirimGoster(mesaj)
    print("Oto-Script: " .. mesaj)
end

-- Ana Ayarlar
local function saveMainSettings(radiusText, spiralStepText, voteSelection, seqActive, mainSpecActive, lobbyActive, lobbyMode, lobbyAltCode, mainLoopList)
    local settings_table = {
        radius = tonumber(radiusText) or 50,
        spiral_step = tonumber(spiralStepText) or 2,
        vote = voteSelection,
        sequence_system_active = seqActive,
        main_special_active = mainSpecActive,
        lobby_auto_active = lobbyActive,
        lobby_auto_mode = lobbyMode,
        lobby_alt_code = lobbyAltCode,
        main_loop_list = mainLoopList
    }
    pcall(function()
        if not isfolder(settings_folder) then makefolder(settings_folder) end
        writefile(main_settings_file, HttpService:JSONEncode(settings_table))
        bildirimGoster("Ana ayarlar kaydedildi.")
    end)
end

local function loadMainSettings()
    local default = { radius = 50, spiral_step = 2, vote = "replay", sequence_system_active = true, main_special_active = true, lobby_auto_active = false, lobby_auto_mode = "Event", lobby_alt_code = "", main_loop_list = YERLESTIRILECEK_BIRIM_SIRALAMASI }
    local s, d = pcall(function() return readfile(main_settings_file) end)
    if s and d and d ~= "" then
        local s2, d2 = pcall(function() return HttpService:JSONDecode(d) end)
        if s2 and type(d2) == "table" then
            for k, v in pairs(default) do if d2[k] == nil then d2[k] = v end end
            YERLESTIRILECEK_BIRIM_SIRALAMASI = d2.main_loop_list -- Kaydedilen listeyi yükle
            return d2
        end
    end
    return default
end

-- Sıralama Ayarları
local function saveSequence(sequenceName, sequenceData, triggerArea, shouldRepeat)
    if not sequenceName or sequenceName == "" then return end
    pcall(function()
        if not isfolder(settings_folder) then makefolder(settings_folder) end
        if not isfolder(sequences_folder) then makefolder(sequences_folder) end
        local dataToSave = {
            name = sequenceName,
            trigger_area = triggerArea,
            tasks = sequenceData,
            repeat_sequence = shouldRepeat,
            last_modified = os.time()
        }
        writefile(sequences_folder .. "/" .. sequenceName .. ".json", HttpService:JSONEncode(dataToSave))
        bildirimGoster("'"..sequenceName.."' sıralaması kaydedildi.")
    end)
end

local all_sequences_cache = {}
local function loadAllSequences()
    local loaded_sequences = {}
    local success, files = pcall(function() return listfiles(sequences_folder) end)
    if success and files then
        for _, file in ipairs(files) do
            if file:sub(-5) == ".json" then
                local s, d = pcall(function() return readfile(file) end)
                if s and d and d ~= "" then
                    local s2, d2 = pcall(function() return HttpService:JSONDecode(d) end)
                    if s2 and d2 then table.insert(loaded_sequences, d2) end
                end
            end
        end
    end
    if #loaded_sequences == 0 then
        local default_seq = {
            {
                name = "Varsayılan Görev",
                trigger_area = {pos = {X=-26.48, Y=24.38, Z=-41.63}, radius = 500},
                last_modified = os.time(),
                repeat_sequence = false,
                tasks = {
                    {type="Place", start_time=0, end_time=60, interval=2, id="9f19e059d65642f", origin={X=-16.1, Y=35.8, Z=-37.7}, direction={X=0,Y=-1,Z=0}},
                    {type="Upgrade", start_time=1, end_time=60, interval=0.5, id="9f19e059d65642f"},
                    {type="Place", start_time=60, end_time=162, interval=5, id="cda8bd1e49cb4e6", origin={X=-21.9, Y=35.8, Z=-41.6}, direction={X=0,Y=-1,Z=0}},
                    {type="Next Event", start_time=480, end_time=600, interval=10}
                }
            }
        }
        all_sequences_cache = default_seq
        return default_seq
    end

    table.sort(loaded_sequences, function(a, b)
        return (a.last_modified or 0) > (b.last_modified or 0)
    end)

    all_sequences_cache = loaded_sequences
    return loaded_sequences
end


--#region Gelişmiş Menü Arayüzü
local specialAreaStatusLabel, sequenceStatusLabel, sequenceNameLabel, sequenceProgressLabel, currentTaskLabel, lobbyStatusLabel

local function getPlacedUnitBaseIds()
    local unitIds = {}
    local seenIds = {}
    local unitsFolder = Workspace:FindFirstChild("_UNITS")
    if unitsFolder then
        for _, unit in ipairs(unitsFolder:GetChildren()) do
            local unitId = unit.Name:sub(1, 15)
            if unitId and #unitId == 15 and not seenIds[unitId] then
                table.insert(unitIds, unitId)
                seenIds[unitId] = true
            end
        end
    end
    return unitIds
end

local guiSuccess, guiError = pcall(function()
    local savedSettings = loadMainSettings()
    sonucSecimi = savedSettings.vote
    sequenceSystemActive = savedSettings.sequence_system_active
    mainAndSpecialActive = savedSettings.main_special_active
    lobbyAutomationActive = savedSettings.lobby_auto_active
    lobbyNextMode = savedSettings.lobby_auto_mode
    lobbyAlternativeCode = savedSettings.lobby_alt_code

    local screenGui = Instance.new("ScreenGui"); screenGui.Name = "AutoScriptGUI"; screenGui.Parent = PlayerGui; screenGui.ResetOnSpawn = false
    
    local mainFrame = Instance.new("Frame"); mainFrame.Name = "MainFrame"; mainFrame.Parent = screenGui;
    mainFrame.Size = UDim2.new(0, 320, 0, 600); mainFrame.Position = UDim2.new(0.5, -160, 0.2, 0); mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45); mainFrame.BorderColor3 = Color3.fromRGB(120, 120, 220); mainFrame.BorderSizePixel = 2; mainFrame.Visible = true;
    mainFrame.BackgroundTransparency = 0.1
    
    local titleBar = Instance.new("TextLabel"); titleBar.Name = "TitleBar"; titleBar.Parent = mainFrame; titleBar.Size = UDim2.new(1, 0, 0, 30); titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55); titleBar.Text = "Oto-Script Menüsü v29.0"; titleBar.Font = Enum.Font.SourceSansBold; titleBar.TextSize = 16; titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
    
    local contentFrame = Instance.new("ScrollingFrame"); contentFrame.Parent = mainFrame; contentFrame.Size = UDim2.new(1, 0, 1, -30); contentFrame.Position = UDim2.new(0, 0, 0, 30); contentFrame.BackgroundTransparency = 1; contentFrame.CanvasSize = UDim2.new(0,0,0,710); contentFrame.ScrollBarThickness = 6;
    
    local mainActionButton = Instance.new("TextButton"); mainActionButton.Parent = contentFrame; mainActionButton.Size = UDim2.new(1, -20, 0, 40); mainActionButton.Position = UDim2.new(0, 10, 0, 10); mainActionButton.BackgroundColor3 = Color3.fromRGB(80, 200, 120); mainActionButton.Text = "Script: AÇIK"; mainActionButton.Font = Enum.Font.SourceSansBold; mainActionButton.TextSize = 18; mainActionButton.TextColor3 = Color3.fromRGB(255,255,255)
    
    lobbyStatusLabel = Instance.new("TextLabel"); lobbyStatusLabel.Parent = contentFrame; lobbyStatusLabel.Size = UDim2.new(1, -20, 0, 20); lobbyStatusLabel.Position = UDim2.new(0, 10, 0, 60); lobbyStatusLabel.BackgroundTransparency = 1; lobbyStatusLabel.Text = "Konum: Bilinmiyor..."; lobbyStatusLabel.Font = Enum.Font.SourceSansBold; lobbyStatusLabel.TextSize = 14; lobbyStatusLabel.TextColor3 = Color3.fromRGB(255,255,255); lobbyStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    specialAreaStatusLabel = Instance.new("TextLabel"); specialAreaStatusLabel.Parent = contentFrame; specialAreaStatusLabel.Size = UDim2.new(1, -20, 0, 20); specialAreaStatusLabel.Position = UDim2.new(0, 10, 0, 85); specialAreaStatusLabel.BackgroundTransparency = 1; specialAreaStatusLabel.Text = "Özel Alan: Bekleniyor..."; specialAreaStatusLabel.Font = Enum.Font.SourceSansBold; specialAreaStatusLabel.TextSize = 14; specialAreaStatusLabel.TextColor3 = Color3.fromRGB(255,255,255); specialAreaStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    sequenceStatusLabel = Instance.new("TextLabel"); sequenceStatusLabel.Parent = contentFrame; sequenceStatusLabel.Size = UDim2.new(1, -20, 0, 20); sequenceStatusLabel.Position = UDim2.new(0, 10, 0, 110); sequenceStatusLabel.BackgroundTransparency = 1; sequenceStatusLabel.Text = "Görev Sıralaması: PASİF"; sequenceStatusLabel.Font = Enum.Font.SourceSansBold; sequenceStatusLabel.TextSize = 14; sequenceStatusLabel.TextColor3 = Color3.fromRGB(220, 80, 80); sequenceStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    sequenceNameLabel = Instance.new("TextLabel"); sequenceNameLabel.Parent = contentFrame; sequenceNameLabel.Size=UDim2.new(1,-20,0,20); sequenceNameLabel.Position=UDim2.new(0,10,0,135); sequenceNameLabel.BackgroundTransparency=1; sequenceNameLabel.Text="Sıralama: -"; sequenceNameLabel.TextColor3=Color3.fromRGB(255,255,255);
    sequenceProgressLabel = Instance.new("TextLabel"); sequenceProgressLabel.Parent = contentFrame; sequenceProgressLabel.Size=UDim2.new(1,-20,0,20); sequenceProgressLabel.Position=UDim2.new(0,10,0,155); sequenceProgressLabel.BackgroundTransparency=1; sequenceProgressLabel.Text="İlerleme: -"; sequenceProgressLabel.TextColor3=Color3.fromRGB(255,255,255);
    currentTaskLabel = Instance.new("TextLabel"); currentTaskLabel.Parent = contentFrame; currentTaskLabel.Size=UDim2.new(1,-20,0,20); currentTaskLabel.Position=UDim2.new(0,10,0,175); currentTaskLabel.BackgroundTransparency=1; currentTaskLabel.Text="Mevcut Görev: -"; currentTaskLabel.TextColor3=Color3.fromRGB(255,255,255);

    local sequenceSystemLabel = Instance.new("TextLabel"); sequenceSystemLabel.Parent = contentFrame; sequenceSystemLabel.Size=UDim2.new(0.5,-15,0,20); sequenceSystemLabel.Position=UDim2.new(0,10,0,205); sequenceSystemLabel.BackgroundTransparency=1; sequenceSystemLabel.Text="Sıralama Sistemi:"; sequenceSystemLabel.Font=Enum.Font.SourceSans; sequenceSystemLabel.TextSize=14; sequenceSystemLabel.TextColor3=Color3.fromRGB(255,255,255); sequenceSystemLabel.TextXAlignment=Enum.TextXAlignment.Left;
    local toggleSequenceSystemButton = Instance.new("TextButton"); toggleSequenceSystemButton.Parent = contentFrame; toggleSequenceSystemButton.Size=UDim2.new(0.5,-15,0,30); toggleSequenceSystemButton.Position=UDim2.new(0.5,5,0,200); toggleSequenceSystemButton.Font=Enum.Font.SourceSansBold; toggleSequenceSystemButton.TextColor3=Color3.fromRGB(255,255,255);
    
    local mainSpecialLabel = Instance.new("TextLabel"); mainSpecialLabel.Parent = contentFrame; mainSpecialLabel.Size=UDim2.new(0.5,-15,0,20); mainSpecialLabel.Position=UDim2.new(0,10,0,240); mainSpecialLabel.BackgroundTransparency=1; mainSpecialLabel.Text="Ana/Özel Alanlar:"; mainSpecialLabel.Font=Enum.Font.SourceSans; mainSpecialLabel.TextSize=14; mainSpecialLabel.TextColor3=Color3.fromRGB(255,255,255); mainSpecialLabel.TextXAlignment=Enum.TextXAlignment.Left;
    local toggleMainSpecialButton = Instance.new("TextButton"); toggleMainSpecialButton.Parent = contentFrame; toggleMainSpecialButton.Size=UDim2.new(0.5,-15,0,30); toggleMainSpecialButton.Position=UDim2.new(0.5,5,0,235); toggleMainSpecialButton.Font=Enum.Font.SourceSansBold; toggleMainSpecialButton.TextColor3=Color3.fromRGB(255,255,255);

    local radiusLabel = Instance.new("TextLabel"); radiusLabel.Parent = contentFrame; radiusLabel.Size = UDim2.new(0.5, -15, 0, 20); radiusLabel.Position = UDim2.new(0, 10, 0, 275); radiusLabel.BackgroundTransparency = 1; radiusLabel.Text = "Maksimum Yarıçap:"; radiusLabel.Font = Enum.Font.SourceSans; radiusLabel.TextSize = 14; radiusLabel.TextColor3 = Color3.fromRGB(255,255,255); radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
    local radiusInputBox = Instance.new("TextBox"); radiusInputBox.Parent = contentFrame; radiusInputBox.Size = UDim2.new(0.5, -15, 0, 30); radiusInputBox.Position = UDim2.new(0.5, 5, 0, 270); radiusInputBox.BackgroundColor3 = Color3.fromRGB(25, 25, 35); radiusInputBox.TextColor3 = Color3.fromRGB(220, 220, 220); radiusInputBox.Text = tostring(savedSettings.radius); radiusInputBox.Font = Enum.Font.SourceSans; radiusInputBox.TextSize = 14; radiusInputBox.ClearTextOnFocus = false; radiusInputBox.TextXAlignment = Enum.TextXAlignment.Center
    
    local spiralStepLabel = Instance.new("TextLabel"); spiralStepLabel.Parent = contentFrame; spiralStepLabel.Size=UDim2.new(0.5,-15,0,20); spiralStepLabel.Position=UDim2.new(0,10,0,310); spiralStepLabel.BackgroundTransparency=1; spiralStepLabel.Text="Daire Adımı (Spiral):"; spiralStepLabel.Font=Enum.Font.SourceSans; spiralStepLabel.TextSize=14; spiralStepLabel.TextColor3=Color3.fromRGB(255,255,255); spiralStepLabel.TextXAlignment=Enum.TextXAlignment.Left
    local spiralStepInputBox = Instance.new("TextBox"); spiralStepInputBox.Parent = contentFrame; spiralStepInputBox.Size=UDim2.new(0.5,-15,0,30); spiralStepInputBox.Position=UDim2.new(0.5,5,0,305); spiralStepInputBox.BackgroundColor3=Color3.fromRGB(25,25,35); spiralStepInputBox.TextColor3=Color3.fromRGB(220,220,220); spiralStepInputBox.Text=tostring(savedSettings.spiral_step); spiralStepInputBox.Font=Enum.Font.SourceSans; spiralStepInputBox.TextSize=14; spiralStepInputBox.ClearTextOnFocus=false; spiralStepInputBox.TextXAlignment=Enum.TextXAlignment.Center
    
    local secimLabel = Instance.new("TextLabel"); secimLabel.Parent = contentFrame; secimLabel.Size = UDim2.new(1, -20, 0, 20); secimLabel.Position = UDim2.new(0, 10, 0, 345); secimLabel.BackgroundTransparency = 1; secimLabel.Text = "Döngü Sonu Seçimi:"; secimLabel.Font = Enum.Font.SourceSans; secimLabel.TextSize = 14; secimLabel.TextColor3 = Color3.fromRGB(255,255,255); secimLabel.TextXAlignment = Enum.TextXAlignment.Left
    local replayButton = Instance.new("TextButton"); replayButton.Parent = contentFrame; replayButton.Size = UDim2.new(0.5, -15, 0, 40); replayButton.Position = UDim2.new(0, 10, 0, 370); replayButton.Text = "Tekrar"; replayButton.Font = Enum.Font.SourceSansBold; replayButton.TextSize = 16; replayButton.TextColor3=Color3.fromRGB(255,255,255)
    local nextButton = Instance.new("TextButton"); nextButton.Parent = contentFrame; nextButton.Size = UDim2.new(0.5, -15, 0, 40); nextButton.Position = UDim2.new(0.5, 5, 0, 370); nextButton.Text = "Sonraki"; nextButton.Font = Enum.Font.SourceSansBold; nextButton.TextSize = 16; nextButton.TextColor3=Color3.fromRGB(255,255,255)
    
    local lobbyLabel = Instance.new("TextLabel"); lobbyLabel.Parent = contentFrame; lobbyLabel.Size=UDim2.new(1,-20,0,20); lobbyLabel.Position=UDim2.new(0,10,0,420); lobbyLabel.BackgroundTransparency=1; lobbyLabel.Text="Lobi Otomasyonu:"; lobbyLabel.Font=Enum.Font.SourceSansBold; lobbyLabel.TextColor3=Color3.fromRGB(255,255,255); lobbyLabel.TextXAlignment=Enum.TextXAlignment.Left
    local lobbyToggleButton = Instance.new("TextButton"); lobbyToggleButton.Parent = contentFrame; lobbyToggleButton.Size=UDim2.new(0.25,-15,0,40); lobbyToggleButton.Position=UDim2.new(0,10,0,445); lobbyToggleButton.Font=Enum.Font.SourceSansBold; lobbyToggleButton.TextColor3=Color3.fromRGB(255,255,255)
    local lobbyEventButton = Instance.new("TextButton"); lobbyEventButton.Parent = contentFrame; lobbyEventButton.Size=UDim2.new(0.25,-15,0,40); lobbyEventButton.Position=UDim2.new(0.25,5,0,445); lobbyEventButton.Text="Event"; lobbyEventButton.Font=Enum.Font.SourceSansBold; lobbyEventButton.TextColor3=Color3.fromRGB(255,255,255)
    local lobbyInfiniteButton = Instance.new("TextButton"); lobbyInfiniteButton.Parent = contentFrame; lobbyInfiniteButton.Size=UDim2.new(0.25,-15,0,40); lobbyInfiniteButton.Position=UDim2.new(0.5,10,0,445); lobbyInfiniteButton.Text="Infinite"; lobbyInfiniteButton.Font=Enum.Font.SourceSansBold; lobbyInfiniteButton.TextColor3=Color3.fromRGB(255,255,255)
    local lobbyAltButton = Instance.new("TextButton"); lobbyAltButton.Parent = contentFrame; lobbyAltButton.Size=UDim2.new(0.25,-15,0,40); lobbyAltButton.Position=UDim2.new(0.75,15,0,445); lobbyAltButton.Text="Alternatif"; lobbyAltButton.Font=Enum.Font.SourceSansBold; lobbyAltButton.TextColor3=Color3.fromRGB(255,255,255)
    local lobbyAltCodeInput = Instance.new("TextBox"); lobbyAltCodeInput.Parent = contentFrame; lobbyAltCodeInput.Size=UDim2.new(1,-20,0,60); lobbyAltCodeInput.Position=UDim2.new(0,10,0,490); lobbyAltCodeInput.Visible=false; lobbyAltCodeInput.MultiLine=true; lobbyAltCodeInput.Text=lobbyAlternativeCode; lobbyAltCodeInput.PlaceholderText="Alternatif modu için LUA kodunu buraya girin...";
    
    local saveButton = Instance.new("TextButton"); saveButton.Parent = contentFrame; saveButton.Size = UDim2.new(1, -20, 0, 30); saveButton.Position = UDim2.new(0, 10, 0, 560); saveButton.BackgroundColor3 = Color3.fromRGB(80, 160, 220); saveButton.Text = "Ana Ayarları Kaydet"; saveButton.Font = Enum.Font.SourceSansBold; saveButton.TextSize = 16; saveButton.TextColor3=Color3.fromRGB(255,255,255)

    local updateMainListButton = Instance.new("TextButton"); updateMainListButton.Parent=contentFrame; updateMainListButton.Size=UDim2.new(1,-20,0,40); updateMainListButton.Position=UDim2.new(0,10,0,600); updateMainListButton.BackgroundColor3=Color3.fromRGB(180, 150, 50); updateMainListButton.Text="Ana Döngü Listesini Güncelle"; updateMainListButton.Font=Enum.Font.SourceSansBold; updateMainListButton.TextSize=18; updateMainListButton.TextColor3=Color3.fromRGB(255,255,255)

    local openEditorButton = Instance.new("TextButton"); openEditorButton.Parent = contentFrame; openEditorButton.Size = UDim2.new(1, -20, 0, 40); openEditorButton.Position = UDim2.new(0, 10, 0, 650); openEditorButton.BackgroundColor3 = Color3.fromRGB(180, 120, 50); openEditorButton.Text = "Sıralama Editörünü Aç"; openEditorButton.Font = Enum.Font.SourceSansBold; openEditorButton.TextSize = 18; openEditorButton.TextColor3=Color3.fromRGB(255,255,255)

    local toggleIcon = Instance.new("TextButton"); toggleIcon.Parent = screenGui; toggleIcon.Size = UDim2.new(0, 50, 0, 50); toggleIcon.Position = UDim2.new(0, 10, 0.2, 0); toggleIcon.BackgroundColor3 = Color3.fromRGB(45, 45, 55); toggleIcon.BorderColor3 = Color3.fromRGB(120, 120, 220); toggleIcon.BorderSizePixel = 1; toggleIcon.Text = "M"; toggleIcon.Font = Enum.Font.SourceSansBold; toggleIcon.TextSize = 24; toggleIcon.TextColor3 = Color3.fromRGB(255, 255, 255); toggleIcon.Visible = false;
    local closeButton = Instance.new("TextButton"); closeButton.Parent = titleBar; closeButton.Size = UDim2.new(0, 24, 0, 24); closeButton.Position = UDim2.new(1, -28, 0.5, -12); closeButton.BackgroundColor3 = Color3.fromRGB(220, 80, 80); closeButton.Text = "X"; closeButton.Font = Enum.Font.SourceSansBold; closeButton.TextSize = 16; closeButton.TextColor3 = Color3.fromRGB(255, 255, 255);
    
    local function updateVoteButtons()
        replayButton.BackgroundColor3 = (sonucSecimi == "replay") and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(80, 80, 90)
        nextButton.BackgroundColor3 = (sonucSecimi == "next_story") and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(80, 80, 90)
    end
    
    local function updateLobbyButtons()
        lobbyToggleButton.Text = lobbyAutomationActive and "Aktif" or "Pasif"
        lobbyToggleButton.BackgroundColor3 = lobbyAutomationActive and Color3.fromRGB(80,200,120) or Color3.fromRGB(220,80,80)
        lobbyEventButton.BackgroundColor3 = (lobbyNextMode == "Event") and Color3.fromRGB(80,160,220) or Color3.fromRGB(80,80,90)
        lobbyInfiniteButton.BackgroundColor3 = (lobbyNextMode == "Infinite") and Color3.fromRGB(80,160,220) or Color3.fromRGB(80,80,90)
        lobbyAltButton.BackgroundColor3 = (lobbyNextMode == "Alternative") and Color3.fromRGB(80,160,220) or Color3.fromRGB(80,80,90)
        lobbyAltCodeInput.Visible = (lobbyNextMode == "Alternative")
        contentFrame.CanvasSize = UDim2.new(0,0,0, (lobbyNextMode == "Alternative") and 780 or 710)
    end
    
    local function updateSequenceSystemButton()
        toggleSequenceSystemButton.Text = sequenceSystemActive and "Aktif" or "Pasif"
        toggleSequenceSystemButton.BackgroundColor3 = sequenceSystemActive and Color3.fromRGB(80,200,120) or Color3.fromRGB(220,80,80)
    end

    local function updateMainSpecialButton()
        toggleMainSpecialButton.Text = mainAndSpecialActive and "Aktif" or "Pasif"
        toggleMainSpecialButton.BackgroundColor3 = mainAndSpecialActive and Color3.fromRGB(80,200,120) or Color3.fromRGB(220,80,80)
    end

    updateVoteButtons()
    updateLobbyButtons()
    updateSequenceSystemButton()
    updateMainSpecialButton()

    closeButton.MouseButton1Click:Connect(function() mainFrame.Visible = false; toggleIcon.Visible = true end)
    toggleIcon.MouseButton1Click:Connect(function() mainFrame.Visible = true; toggleIcon.Visible = false end)
    mainActionButton.MouseButton1Click:Connect(function() scriptAktif = not scriptAktif; mainActionButton.Text = scriptAktif and "Script: AÇIK" or "Script: KAPALI"; mainActionButton.BackgroundColor3 = scriptAktif and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(220, 80, 80) end)
    replayButton.MouseButton1Click:Connect(function() sonucSecimi = "replay"; updateVoteButtons() end)
    nextButton.MouseButton1Click:Connect(function() sonucSecimi = "next_story"; updateVoteButtons() end)
    toggleSequenceSystemButton.MouseButton1Click:Connect(function() sequenceSystemActive = not sequenceSystemActive; updateSequenceSystemButton() end)
    toggleMainSpecialButton.MouseButton1Click:Connect(function() mainAndSpecialActive = not mainAndSpecialActive; updateMainSpecialButton() end)
    lobbyToggleButton.MouseButton1Click:Connect(function() lobbyAutomationActive = not lobbyAutomationActive; updateLobbyButtons() end)
    lobbyEventButton.MouseButton1Click:Connect(function() lobbyNextMode = "Event"; updateLobbyButtons() end)
    lobbyInfiniteButton.MouseButton1Click:Connect(function() lobbyNextMode = "Infinite"; updateLobbyButtons() end)
    lobbyAltButton.MouseButton1Click:Connect(function() lobbyNextMode = "Alternative"; updateLobbyButtons() end)
    saveButton.MouseButton1Click:Connect(function()
        lobbyAlternativeCode = lobbyAltCodeInput.Text
        saveMainSettings(radiusInputBox.Text, spiralStepInputBox.Text, sonucSecimi, sequenceSystemActive, mainAndSpecialActive, lobbyAutomationActive, lobbyNextMode, lobbyAlternativeCode, YERLESTIRILECEK_BIRIM_SIRALAMASI)
    end)
    
    updateMainListButton.MouseButton1Click:Connect(function()
        local newIds = getPlacedUnitBaseIds()
        local addedCount = 0
        local existingIds = {}
        for _, id in ipairs(YERLESTIRILECEK_BIRIM_SIRALAMASI) do
            existingIds[id] = true
        end
        for _, newId in ipairs(newIds) do
            if not existingIds[newId] then
                table.insert(YERLESTIRILECEK_BIRIM_SIRALAMASI, newId)
                existingIds[newId] = true
                addedCount = addedCount + 1
            end
        end
        if addedCount > 0 then
            bildirimGoster(addedCount .. " yeni birim ID'si ana döngü listesine eklendi.")
        else
            bildirimGoster("Listeye eklenecek yeni birim ID'si bulunamadı.")
        end
    end)

    local function makeDraggable(frameToDrag, handle)
        handle = handle or frameToDrag
        local dragging = false
        local dragStart = nil
        local startPos = nil

        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frameToDrag.Position
                
                local conn 
                conn = input.Changed:Connect(function() 
                    if input.UserInputState == Enum.UserInputState.End then 
                        dragging = false 
                        conn:Disconnect() 
                    end 
                end)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                frameToDrag.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
    makeDraggable(mainFrame, titleBar); makeDraggable(toggleIcon)
    
    local editorFrame = Instance.new("Frame"); editorFrame.Name = "SequenceEditor"; editorFrame.Parent = screenGui; editorFrame.Size = UDim2.new(0, 800, 0, 600); editorFrame.Position = UDim2.new(0.5, -400, 0.5, -300); editorFrame.BackgroundColor3 = Color3.fromRGB(40, 42, 54); editorFrame.BorderColor3 = Color3.fromRGB(150, 120, 250); editorFrame.BorderSizePixel = 2; editorFrame.Visible = false; editorFrame.BackgroundTransparency = 0.05;
    makeDraggable(editorFrame)
    
    local editorTitle = Instance.new("TextLabel"); editorTitle.Parent = editorFrame; editorTitle.Size = UDim2.new(1, 0, 0, 30); editorTitle.BackgroundColor3 = Color3.fromRGB(45, 45, 55); editorTitle.Text = "Sıralama Editörü"; editorTitle.Font = Enum.Font.SourceSansBold; editorTitle.TextSize = 16; editorTitle.TextColor3 = Color3.fromRGB(255, 255, 255);
    local editorCloseButton = Instance.new("TextButton"); editorCloseButton.Parent = editorTitle; editorCloseButton.Size = UDim2.new(0, 24, 0, 24); editorCloseButton.Position = UDim2.new(1, -28, 0.5, -12); editorCloseButton.BackgroundColor3 = Color3.fromRGB(220, 80, 80); editorCloseButton.Text = "X"; editorCloseButton.Font = Enum.Font.SourceSansBold; editorCloseButton.TextSize = 16; editorCloseButton.TextColor3 = Color3.fromRGB(255, 255, 255);
    
    local sequenceListFrame = Instance.new("ScrollingFrame"); sequenceListFrame.Parent = editorFrame; sequenceListFrame.Size = UDim2.new(0, 200, 1, -120); sequenceListFrame.Position = UDim2.new(0, 10, 0, 40); sequenceListFrame.BackgroundColor3 = Color3.fromRGB(30,30,40); sequenceListFrame.CanvasSize = UDim2.new(0,0,0,0);
    local taskListFrame = Instance.new("ScrollingFrame"); taskListFrame.Parent = editorFrame; taskListFrame.Size = UDim2.new(1, -230, 1, -130); taskListFrame.Position = UDim2.new(0, 220, 0, 80); taskListFrame.BackgroundColor3 = Color3.fromRGB(30,30,40); taskListFrame.CanvasSize = UDim2.new(0,0,0,0);
    
    local sequenceNameInput = Instance.new("TextBox"); sequenceNameInput.Parent = editorFrame; sequenceNameInput.Size = UDim2.new(0, 140, 0, 30); sequenceNameInput.Position = UDim2.new(0, 220, 0, 40); sequenceNameInput.PlaceholderText = "Sıralama Adı"; sequenceNameInput.BackgroundColor3 = Color3.fromRGB(50,50,60); sequenceNameInput.TextColor3 = Color3.new(1,1,1);
    local repeatSequenceButton = Instance.new("TextButton"); repeatSequenceButton.Name = "RepeatButton"; repeatSequenceButton.Parent = editorFrame; repeatSequenceButton.Size=UDim2.new(0,60,0,30); repeatSequenceButton.Position=UDim2.new(0,365,0,40); repeatSequenceButton.Text="Tekrarla"; repeatSequenceButton.Font=Enum.Font.SourceSansBold; repeatSequenceButton.TextColor3 = Color3.fromRGB(255,255,255)
    
    local triggerPosLabel = Instance.new("TextLabel"); triggerPosLabel.Parent = editorFrame; triggerPosLabel.Position = UDim2.new(0, 430, 0, 45); triggerPosLabel.Size = UDim2.new(0,80,0,20); triggerPosLabel.Text = "Tetikleyici:"; triggerPosLabel.BackgroundTransparency = 1; triggerPosLabel.TextColor3=Color3.new(1,1,1);
    local triggerX = Instance.new("TextBox"); triggerX.Parent = editorFrame; triggerX.Size = UDim2.new(0,50,0,30); triggerX.Position = UDim2.new(0, 500, 0, 40); triggerX.PlaceholderText = "X"; triggerX.BackgroundColor3=Color3.fromRGB(50,50,60);triggerX.TextColor3=Color3.new(1,1,1)
    local triggerY = Instance.new("TextBox"); triggerY.Parent = editorFrame; triggerY.Size = UDim2.new(0,50,0,30); triggerY.Position = UDim2.new(0, 555, 0, 40); triggerY.PlaceholderText = "Y"; triggerY.BackgroundColor3=Color3.fromRGB(50,50,60);triggerY.TextColor3=Color3.new(1,1,1)
    local triggerZ = Instance.new("TextBox"); triggerZ.Parent = editorFrame; triggerZ.Size = UDim2.new(0,50,0,30); triggerZ.Position = UDim2.new(0, 610, 0, 40); triggerZ.PlaceholderText = "Z"; triggerZ.BackgroundColor3=Color3.fromRGB(50,50,60);triggerZ.TextColor3=Color3.new(1,1,1)
    local triggerR = Instance.new("TextBox"); triggerR.Parent = editorFrame; triggerR.Size = UDim2.new(0,50,0,30); triggerR.Position = UDim2.new(0, 665, 0, 40); triggerR.PlaceholderText = "R"; triggerR.BackgroundColor3=Color3.fromRGB(50,50,60);triggerR.TextColor3=Color3.new(1,1,1)
    local getTriggerPosButton = Instance.new("TextButton"); getTriggerPosButton.Parent = editorFrame; getTriggerPosButton.Size = UDim2.new(0,80,0,30); getTriggerPosButton.Position = UDim2.new(0,718,0,40); getTriggerPosButton.Text = "Konum Al"; getTriggerPosButton.TextColor3 = Color3.fromRGB(255,255,255)
    
    local function clearEditor()
        sequenceNameInput.Text = "";
        triggerX.Text = ""; triggerY.Text = ""; triggerZ.Text = ""; triggerR.Text = ""
        repeatSequenceButton.BackgroundColor3 = Color3.fromRGB(80,80,90)
        repeatSequenceButton.Text = "Tekrarla: KAPALI"
        for _,v in ipairs(taskListFrame:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
        taskListFrame.CanvasSize = UDim2.new(0,0,0,0)
    end
    
    local function createTaskFrame(taskData)
        local taskFrame = Instance.new("Frame"); taskFrame.Parent = taskListFrame; taskFrame.Size = UDim2.new(1, -10, 0, 150); taskFrame.BackgroundColor3 = Color3.fromRGB(50, 52, 64);
        taskFrame.ClipsDescendants = false

        -- ETİKETLER
        local typeLabel = Instance.new("TextLabel"); typeLabel.Parent = taskFrame; typeLabel.Size=UDim2.new(0,80,0,15);typeLabel.Position=UDim2.new(0,5,0,0);typeLabel.Text="Tür:";typeLabel.BackgroundTransparency=1;typeLabel.TextColor3=Color3.fromRGB(255,255,255);typeLabel.TextXAlignment=Enum.TextXAlignment.Left;
        local idLabel = Instance.new("TextLabel"); idLabel.Parent = taskFrame; idLabel.Size=UDim2.new(0,150,0,15);idLabel.Position=UDim2.new(0,90,0,0);idLabel.Text="Unit ID:";idLabel.BackgroundTransparency=1;idLabel.TextColor3=Color3.fromRGB(255,255,255);idLabel.TextXAlignment=Enum.TextXAlignment.Left;
        local timeLabel = Instance.new("TextLabel"); timeLabel.Parent = taskFrame; timeLabel.Size=UDim2.new(0,100,0,15);timeLabel.Position=UDim2.new(0,245,0,0);timeLabel.Text="Baş. / Bit. Süre";timeLabel.BackgroundTransparency=1;timeLabel.TextColor3=Color3.fromRGB(255,255,255);timeLabel.TextXAlignment=Enum.TextXAlignment.Left;
        local intervalLabel = Instance.new("TextLabel"); intervalLabel.Parent = taskFrame; intervalLabel.Size=UDim2.new(0,50,0,15);intervalLabel.Position=UDim2.new(0,355,0,0);intervalLabel.Text="Aralık";intervalLabel.BackgroundTransparency=1;intervalLabel.TextColor3=Color3.fromRGB(255,255,255);intervalLabel.TextXAlignment=Enum.TextXAlignment.Left;

        -- GÖREV TÜRÜ SEÇİMİ
        local typeButton = Instance.new("TextButton"); typeButton.Name="typeButton"; typeButton.Parent = taskFrame; typeButton.Size = UDim2.new(0, 80, 0, 25); typeButton.Position = UDim2.new(0, 5, 0, 15); typeButton.Text = taskData.type or "Place"; typeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70); typeButton.TextColor3 = Color3.fromRGB(255,255,255)
        local typeDropdown = Instance.new("Frame"); typeDropdown.Parent = editorFrame; typeDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 70); typeDropdown.Visible = false; typeDropdown.ZIndex = 10; typeDropdown.BackgroundTransparency = 0.1
        local typeLayout = Instance.new("UIListLayout"); typeLayout.Parent = typeDropdown; typeLayout.Padding = UDim.new(0,1)
        
        local typeOptions = {"Place", "Upgrade", "Code", "Replay", "Leave", "Next Story", "Next Event"}
        for _, option in ipairs(typeOptions) do
            local optButton = Instance.new("TextButton"); optButton.Parent = typeDropdown; optButton.Size = UDim2.new(1, 0, 0, 25); optButton.Text = option; optButton.BackgroundColor3=Color3.fromRGB(70,70,80);optButton.TextColor3=Color3.fromRGB(255,255,255)
            optButton.MouseButton1Click:Connect(function() typeButton.Text = option; typeDropdown.Visible = false end)
            optButton.MouseEnter:Connect(function() optButton.BackgroundColor3 = Color3.fromRGB(90, 90, 100) end)
            optButton.MouseLeave:Connect(function() optButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80) end)
        end
        typeButton.MouseButton1Click:Connect(function()
            typeDropdown.Size = UDim2.new(0, typeButton.AbsoluteSize.X, 0, #typeDropdown:GetChildren() * 26)
            typeDropdown.Position = UDim2.fromOffset(typeButton.AbsolutePosition.X, typeButton.AbsolutePosition.Y + typeButton.AbsoluteSize.Y)
            typeDropdown.Visible = not typeDropdown.Visible
        end)

        -- DİĞER GİRDİLER
        local selectIdButton = Instance.new("TextButton"); selectIdButton.Parent = taskFrame; selectIdButton.Size = UDim2.new(0, 25, 0, 25); selectIdButton.Position = UDim2.new(0, 90, 0, 15); selectIdButton.Text = "▼"; selectIdButton.BackgroundColor3 = Color3.fromRGB(60,60,70); selectIdButton.TextColor3=Color3.new(1,1,1)
        local inputId = Instance.new("TextBox"); inputId.Name="inputId"; inputId.Parent = taskFrame; inputId.Size = UDim2.new(0, 120, 0, 25); inputId.Position = UDim2.new(0, 120, 0, 15); inputId.Text = taskData.id or ""; inputId.PlaceholderText = "Unit ID";
        local inputStart = Instance.new("TextBox"); inputStart.Name="inputStart"; inputStart.Parent = taskFrame; inputStart.Size = UDim2.new(0, 50, 0, 25); inputStart.Position = UDim2.new(0, 245, 0, 15); inputStart.Text = tostring(taskData.start_time or 0);
        local inputEnd = Instance.new("TextBox"); inputEnd.Name="inputEnd"; inputEnd.Parent = taskFrame; inputEnd.Size = UDim2.new(0, 50, 0, 25); inputEnd.Position = UDim2.new(0, 300, 0, 15); inputEnd.Text = tostring(taskData.end_time or 60);
        local inputInterval = Instance.new("TextBox"); inputInterval.Name="inputInterval"; inputInterval.Parent = taskFrame; inputInterval.Size = UDim2.new(0, 50, 0, 25); inputInterval.Position = UDim2.new(0, 355, 0, 15); inputInterval.Text = tostring(taskData.interval or 1);
        
        local deleteButton = Instance.new("TextButton"); deleteButton.Parent = taskFrame; deleteButton.Size = UDim2.new(0, 25, 0, 25); deleteButton.Position = UDim2.new(1, -30, 0, 15); deleteButton.Text = "X"; deleteButton.BackgroundColor3 = Color3.fromRGB(200,80,80);
        deleteButton.MouseButton1Click:Connect(function() taskFrame:Destroy() end)

        local idDropdown = Instance.new("ScrollingFrame"); idDropdown.Parent = editorFrame; idDropdown.BackgroundColor3 = Color3.fromRGB(60,60,70); idDropdown.Visible = false; idDropdown.ZIndex = 10; idDropdown.BackgroundTransparency = 0.1
        local idLayout = Instance.new("UIListLayout"); idLayout.Parent = idDropdown; idLayout.Padding = UDim.new(0,1)
        
        selectIdButton.MouseButton1Click:Connect(function()
            if idDropdown.Visible then idDropdown.Visible = false; return end
            for _,v in ipairs(idDropdown:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
            local currentIds = getPlacedUnitBaseIds()
            if #currentIds == 0 then table.insert(currentIds, "Birim Yok") end
            for _, unitId in ipairs(currentIds) do
                local unitButton = Instance.new("TextButton"); unitButton.Parent = idDropdown; unitButton.Size=UDim2.new(1,0,0,25); unitButton.Text = unitId; unitButton.BackgroundColor3=Color3.fromRGB(70,70,80);unitButton.TextColor3=Color3.fromRGB(255,255,255); unitButton.TextXAlignment = Enum.TextXAlignment.Left;
                unitButton.MouseButton1Click:Connect(function() inputId.Text = unitId; idDropdown.Visible = false end)
                unitButton.MouseEnter:Connect(function() unitButton.BackgroundColor3 = Color3.fromRGB(90, 90, 100) end)
                unitButton.MouseLeave:Connect(function() unitButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80) end)
            end
            idDropdown.Size = UDim2.new(0, 150, 0, math.min(#idDropdown:GetChildren() * 26, 120))
            idDropdown.Position = UDim2.fromOffset(selectIdButton.AbsolutePosition.X, selectIdButton.AbsolutePosition.Y + selectIdButton.AbsoluteSize.Y)
            idDropdown.Visible = true
        end)

        local placeFrame = Instance.new("Frame"); placeFrame.Name="placeFrame"; placeFrame.Parent = taskFrame; placeFrame.Size = UDim2.new(1,0,1,-45); placeFrame.Position=UDim2.new(0,0,0,45); placeFrame.BackgroundTransparency = 1; placeFrame.Visible = (taskData.type == "Place")
        local inputOriginX = Instance.new("TextBox"); inputOriginX.Name="inputOriginX"; inputOriginX.Parent = placeFrame; inputOriginX.Size=UDim2.new(0,60,0,25);inputOriginX.Position=UDim2.new(0,5,0,0);inputOriginX.Text = string.format("%.2f", taskData.origin and taskData.origin.X or 0); inputOriginX.PlaceholderText = "Origin X"
        local inputOriginY = Instance.new("TextBox"); inputOriginY.Name="inputOriginY"; inputOriginY.Parent = placeFrame; inputOriginY.Size=UDim2.new(0,60,0,25);inputOriginY.Position=UDim2.new(0,70,0,0);inputOriginY.Text = string.format("%.2f", taskData.origin and taskData.origin.Y or 0); inputOriginY.PlaceholderText = "Origin Y"
        local inputOriginZ = Instance.new("TextBox"); inputOriginZ.Name="inputOriginZ"; inputOriginZ.Parent = placeFrame; inputOriginZ.Size=UDim2.new(0,60,0,25);inputOriginZ.Position=UDim2.new(0,135,0,0);inputOriginZ.Text = string.format("%.2f", taskData.origin and taskData.origin.Z or 0); inputOriginZ.PlaceholderText = "Origin Z"
        local getPosButton = Instance.new("TextButton"); getPosButton.Parent = placeFrame; getPosButton.Size=UDim2.new(0,100,0,25); getPosButton.Position=UDim2.new(0,200,0,0); getPosButton.Text="Konumu Al"; getPosButton.TextColor3=Color3.fromRGB(255,255,255)
        local getMousePosButton = Instance.new("TextButton"); getMousePosButton.Parent = placeFrame; getMousePosButton.Size=UDim2.new(0,120,0,25); getMousePosButton.Position=UDim2.new(0,305,0,0); getMousePosButton.Text="Mouse ile Seç"; getMousePosButton.TextColor3=Color3.fromRGB(255,255,255)
        
        local dirLabel = Instance.new("TextLabel"); dirLabel.Parent = placeFrame; dirLabel.Size=UDim2.new(0,60,0,25); dirLabel.Position=UDim2.new(0,5,0,30); dirLabel.Text="Yön:"; dirLabel.BackgroundTransparency=1; dirLabel.TextColor3=Color3.fromRGB(255,255,255); dirLabel.TextXAlignment=Enum.TextXAlignment.Left;
        local inputDirectionX = Instance.new("TextBox"); inputDirectionX.Name="inputDirectionX"; inputDirectionX.Parent = placeFrame; inputDirectionX.Size=UDim2.new(0,60,0,25);inputDirectionX.Position=UDim2.new(0,70,0,30);inputDirectionX.Text = string.format("%.2f", taskData.direction and taskData.direction.X or 0); inputDirectionX.PlaceholderText = "Dir X"
        local inputDirectionY = Instance.new("TextBox"); inputDirectionY.Name="inputDirectionY"; inputDirectionY.Parent = placeFrame; inputDirectionY.Size=UDim2.new(0,60,0,25);inputDirectionY.Position=UDim2.new(0,135,0,30);inputDirectionY.Text = string.format("%.2f", taskData.direction and taskData.direction.Y or -1); inputDirectionY.PlaceholderText = "Dir Y"
        local inputDirectionZ = Instance.new("TextBox"); inputDirectionZ.Name="inputDirectionZ"; inputDirectionZ.Parent = placeFrame; inputDirectionZ.Size=UDim2.new(0,60,0,25);inputDirectionZ.Position=UDim2.new(0,200,0,30);inputDirectionZ.Text = string.format("%.2f", taskData.direction and taskData.direction.Z or 0); inputDirectionZ.PlaceholderText = "Dir Z"

        getPosButton.MouseButton1Click:Connect(function()
            local char = localPlayer.Character
            if char and char.PrimaryPart then
                local pos = char.PrimaryPart.Position
                inputOriginX.Text = string.format("%.2f",pos.X)
                inputOriginY.Text = string.format("%.2f",pos.Y)
                inputOriginZ.Text = string.format("%.2f",pos.Z)
            end
        end)
        getMousePosButton.MouseButton1Click:Connect(function()
            bildirimGoster("Konum seçmek için haritaya tıklayın...")
            local conn
            conn = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local mouseRay = Workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
                    local raycastResult = Workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000)
                    if raycastResult then
                        local pos = raycastResult.Position
                        inputOriginX.Text = string.format("%.2f", pos.X)
                        inputOriginY.Text = string.format("%.2f", pos.Y)
                        inputOriginZ.Text = string.format("%.2f", pos.Z)
                        bildirimGoster("Konum alındı.")
                    else
                        bildirimGoster("Geçerli bir konum bulunamadı.")
                    end
                    conn:Disconnect()
                end
            end)
        end)

        local codeFrame = Instance.new("Frame"); codeFrame.Name="codeFrame"; codeFrame.Parent = taskFrame; codeFrame.Size = UDim2.new(1,0,1,-45); codeFrame.Position=UDim2.new(0,0,0,45); codeFrame.BackgroundTransparency=1; codeFrame.Visible = (taskData.type == "Code")
        local inputCode = Instance.new("TextBox"); inputCode.Name="inputCode"; inputCode.Parent = codeFrame; inputCode.Size=UDim2.new(1,-10,1,-5); inputCode.Position=UDim2.new(0,5,0,0); inputCode.Text = taskData.code or ""; inputCode.PlaceholderText = "LUA KODUNU GİRİNİZ"; inputCode.TextXAlignment = Enum.TextXAlignment.Left; inputCode.MultiLine = true

        typeButton:GetPropertyChangedSignal("Text"):Connect(function()
            placeFrame.Visible = (typeButton.Text == "Place")
            codeFrame.Visible = (typeButton.Text == "Code")
        end)
    end

    local function loadSequenceIntoEditor(sequenceData)
        clearEditor()
        sequenceNameInput.Text = sequenceData.name or "İsimsiz"
        local ta = sequenceData.trigger_area
        if ta and ta.pos then triggerX.Text=tostring(ta.pos.X); triggerY.Text=tostring(ta.pos.Y); triggerZ.Text=tostring(ta.pos.Z); triggerR.Text=tostring(ta.radius) end
        
        local shouldRepeat = sequenceData.repeat_sequence or false
        repeatSequenceButton.Text = "Tekrarla: " .. (shouldRepeat and "AÇIK" or "KAPALI")
        repeatSequenceButton.BackgroundColor3 = shouldRepeat and Color3.fromRGB(80,200,120) or Color3.fromRGB(80,80,90)

        local listLayout = Instance.new("UIListLayout"); listLayout.Parent = taskListFrame; listLayout.Padding = UDim.new(0, 5);
        for _, task in ipairs(sequenceData.tasks or {}) do createTaskFrame(task) end
        taskListFrame.CanvasSize = UDim2.new(0,0,0, #taskListFrame:GetChildren() * 155)
    end

    local function refreshSequenceList()
        for _,v in ipairs(sequenceListFrame:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        local layout = sequenceListFrame:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
        layout.Parent = sequenceListFrame; layout.Padding = UDim.new(0, 5)

        for _, seqData in ipairs(all_sequences_cache) do
            local seqButton = Instance.new("TextButton"); seqButton.Parent = sequenceListFrame; seqButton.Size = UDim2.new(1, -10, 0, 30); seqButton.Text = seqData.name or "İsimsiz"; seqButton.TextColor3=Color3.fromRGB(255,255,255);
            seqButton.MouseButton1Click:Connect(function() loadSequenceIntoEditor(seqData) end)
        end
        sequenceListFrame.CanvasSize = UDim2.new(0,0,0, #all_sequences_cache * 35)
    end
    
    getTriggerPosButton.MouseButton1Click:Connect(function()
        local char = localPlayer.Character
        if char and char.PrimaryPart then
            local pos = char.PrimaryPart.Position
            triggerX.Text = string.format("%.2f", pos.X)
            triggerY.Text = string.format("%.2f", pos.Y)
            triggerZ.Text = string.format("%.2f", pos.Z)
        end
    end)
    
    openEditorButton.MouseButton1Click:Connect(function()
        sequenceEditorOpen = not sequenceEditorOpen
        editorFrame.Visible = sequenceEditorOpen
        if sequenceEditorOpen then
            loadAllSequences()
            refreshSequenceList()
        end
    end)
    editorCloseButton.MouseButton1Click:Connect(function() sequenceEditorOpen=false; editorFrame.Visible=false; end)

    repeatSequenceButton.MouseButton1Click:Connect(function()
        local currentState = repeatSequenceButton.Text:find("AÇIK")
        local newState = not currentState
        repeatSequenceButton.Text = "Tekrarla: " .. (newState and "AÇIK" or "KAPALI")
        repeatSequenceButton.BackgroundColor3 = newState and Color3.fromRGB(80,200,120) or Color3.fromRGB(80,80,90)
    end)

    local lastUnitIdLabel = Instance.new("TextLabel"); lastUnitIdLabel.Parent = editorFrame; lastUnitIdLabel.Size=UDim2.new(0,200,0,15); lastUnitIdLabel.Position=UDim2.new(0,10,1,-50); lastUnitIdLabel.Text="Son Yerleştirilen ID: -"; lastUnitIdLabel.BackgroundTransparency=1;lastUnitIdLabel.TextColor3=Color3.fromRGB(255,255,255);lastUnitIdLabel.TextXAlignment=Enum.TextXAlignment.Left;
    local copyLastIdButton = Instance.new("TextButton"); copyLastIdButton.Parent=editorFrame; copyLastIdButton.Size=UDim2.new(0,70,0,30);copyLastIdButton.Position=UDim2.new(0,140,1,-55);copyLastIdButton.Text="Kopyala"; copyLastIdButton.TextColor3=Color3.fromRGB(255,255,255)
    copyLastIdButton.MouseButton1Click:Connect(function() if lastPlacedUnitId ~= "" then setclipboard(lastPlacedUnitId); bildirimGoster("ID Kopyalandı: " .. lastPlacedUnitId) end end)
    
    local refreshListButton = Instance.new("TextButton"); refreshListButton.Parent = editorFrame; refreshListButton.Size=UDim2.new(0,120,0,30); refreshListButton.Position=UDim2.new(0,20,1,-80); refreshListButton.Text="Listeyi Yenile"; refreshListButton.TextColor3=Color3.fromRGB(255,255,255)
    refreshListButton.MouseButton1Click:Connect(function() loadAllSequences(); refreshSequenceList() end)

    local function saveCurrentlyEditedSequence()
        local tasks, trigger_area = {}, {}
        for _, frame in ipairs(taskListFrame:GetChildren()) do
            if frame:IsA("Frame") then
                local task = {type=frame.typeButton.Text, id=frame.inputId.Text, start_time=tonumber(frame.inputStart.Text) or 0, end_time=tonumber(frame.inputEnd.Text) or 0, interval=tonumber(frame.inputInterval.Text) or 0}
                if task.type == "Place" then
                    task.origin = {X=tonumber(frame.placeFrame.inputOriginX.Text) or 0, Y=tonumber(frame.placeFrame.inputOriginY.Text) or 0, Z=tonumber(frame.placeFrame.inputOriginZ.Text) or 0}
                    task.direction = {
                        X=tonumber(frame.placeFrame.inputDirectionX.Text) or 0, 
                        Y=tonumber(frame.placeFrame.inputDirectionY.Text) or -1, 
                        Z=tonumber(frame.placeFrame.inputDirectionZ.Text) or 0
                    }
                elseif task.type == "Code" then
                    task.code = frame.codeFrame.inputCode.Text
                end
                table.insert(tasks, task)
            end
        end
        trigger_area = {pos = {X=tonumber(triggerX.Text), Y=tonumber(triggerY.Text), Z=tonumber(triggerZ.Text)}, radius = tonumber(triggerR.Text)}
        local shouldRepeat = repeatSequenceButton.Text:find("AÇIK") and true or false
        saveSequence(sequenceNameInput.Text, tasks, trigger_area, shouldRepeat)
        loadAllSequences()
        refreshSequenceList()
    end

    local saveSequenceButton = Instance.new("TextButton"); saveSequenceButton.Parent = editorFrame; saveSequenceButton.Size=UDim2.new(0,120,0,40); saveSequenceButton.Position=UDim2.new(1,-130,1,-50); saveSequenceButton.Text="Kaydet"; saveSequenceButton.BackgroundColor3=Color3.fromRGB(80,180,120); saveSequenceButton.TextColor3=Color3.fromRGB(255,255,255)
    saveSequenceButton.MouseButton1Click:Connect(saveCurrentlyEditedSequence)
    
    local addNewTaskButton = Instance.new("TextButton"); addNewTaskButton.Parent = editorFrame; addNewTaskButton.Size=UDim2.new(0,120,0,40); addNewTaskButton.Position=UDim2.new(1,-520,1,-50); addNewTaskButton.Text="Yeni Görev Ekle"; addNewTaskButton.TextColor3=Color3.fromRGB(255,255,255)
    addNewTaskButton.MouseButton1Click:Connect(function()
        createTaskFrame({type="Place", start_time=0, end_time=60, interval=1});
        taskListFrame.CanvasSize = UDim2.new(0,0,0, #taskListFrame:GetChildren() * 155)
    end)
    
    local addCurrentUnitsButton = Instance.new("TextButton")
    addCurrentUnitsButton.Parent = editorFrame
    addCurrentUnitsButton.Size = UDim2.new(0, 140, 0, 40)
    addCurrentUnitsButton.Position = UDim2.new(1, -670, 1, -50)
    addCurrentUnitsButton.Text = "Mevcut Unit'leri Ekle"
    addCurrentUnitsButton.BackgroundColor3 = Color3.fromRGB(80, 120, 180)
    addCurrentUnitsButton.TextColor3 = Color3.fromRGB(255, 255, 255)

    addCurrentUnitsButton.MouseButton1Click:Connect(function()
        local unitsFolder = Workspace:FindFirstChild("_UNITS")
        if not unitsFolder then
            bildirimGoster("_UNITS klasörü bulunamadı.")
            return
        end

        local units = unitsFolder:GetChildren()
        if #units == 0 then
            bildirimGoster("Eklenecek aktif unit bulunamadı.")
            return
        end

        for _, unit in ipairs(units) do
            if unit:IsA("Model") then
                local pivot = unit:GetPivot()
                local pos = pivot.Position
                local dir = pivot.LookVector
                local baseId = unit.Name:sub(1, 15)

                -- Place Görevi Oluştur
                local placeTaskData = {
                    type = "Place",
                    id = baseId,
                    start_time = 0,
                    end_time = 200,
                    interval = 20,
                    origin = { X = pos.X, Y = pos.Y, Z = pos.Z },
                    direction = { X = dir.X, Y = dir.Y, Z = dir.Z }
                }
                createTaskFrame(placeTaskData)

                -- Upgrade Görevi Oluştur
                local upgradeTaskData = {
                    type = "Upgrade",
                    id = baseId,
                    start_time = 0,
                    end_time = 200,
                    interval = 20
                }
                createTaskFrame(upgradeTaskData)
            end
        end
        
        taskListFrame.CanvasSize = UDim2.new(0, 0, 0, #taskListFrame:GetChildren() * 155)
        bildirimGoster(#units .. " unit için Place ve Upgrade görevleri eklendi.")
    end)

    local deleteSequenceButton = Instance.new("TextButton"); deleteSequenceButton.Parent = editorFrame; deleteSequenceButton.Size=UDim2.new(0,120,0,40); deleteSequenceButton.Position=UDim2.new(1,-260,1,-50); deleteSequenceButton.Text="Sıralamayı Sil"; deleteSequenceButton.BackgroundColor3 = Color3.fromRGB(200, 80, 80); deleteSequenceButton.TextColor3=Color3.fromRGB(255,255,255)
    deleteSequenceButton.MouseButton1Click:Connect(function()
        local nameToDelete = sequenceNameInput.Text
        if nameToDelete == "Varsayılan Görev" then bildirimGoster("'Varsayılan Görev' silinemez."); return end
        if nameToDelete and nameToDelete ~= "" then
            local s,e = pcall(function() delfile(sequences_folder .. "/" .. nameToDelete .. ".json") end)
            if s then
                bildirimGoster("'"..nameToDelete.."' silindi.")
                loadAllSequences()
                refreshSequenceList()
                clearEditor()
            else
                bildirimGoster("'"..nameToDelete.."' silinemedi. Hata: "..tostring(e))
            end
        else
            bildirimGoster("Silmek için önce bir sıralama yükleyin.")
        end
    end)
    
    local copySequenceButton = Instance.new("TextButton"); copySequenceButton.Parent = editorFrame; copySequenceButton.Size=UDim2.new(0,120,0,40); copySequenceButton.Position=UDim2.new(1,-390,1,-50); copySequenceButton.Text="Sıralamayı Kopyala"; copySequenceButton.TextColor3=Color3.fromRGB(255,255,255)
    copySequenceButton.MouseButton1Click:Connect(function()
        local currentName = sequenceNameInput.Text
        if not currentName or currentName == "" then
            bildirimGoster("Kopyalamak için önce bir sıralama yükleyin.")
            return
        end
        sequenceNameInput.Text = currentName .. " - Kopya"
        saveCurrentlyEditedSequence()
    end)
end)
if not guiSuccess then bildirimGoster("KRİTİK HATA: Menü oluşturulamadı!") warn("Menü hatası:", guiError) return end
--#endregion

bildirimGoster("Script Başlatıldı! Menü oluşturuldu.")

local endpoints, spawnUnitRemote, upgradeUnitRemote, voteRemote, matchmakingRemote, teleportToLobby, joinLobby, lockLevel, requestLeaderboard
pcall(function()
    endpoints = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server")
    spawnUnitRemote = endpoints:WaitForChild("spawn_unit")
    upgradeUnitRemote = endpoints:WaitForChild("upgrade_unit_ingame")
    voteRemote = endpoints:WaitForChild("set_game_finished_vote")
    matchmakingRemote = endpoints:WaitForChild("request_matchmaking")
    teleportToLobby = endpoints:WaitForChild("teleport_back_to_lobby")
    joinLobby = endpoints:WaitForChild("request_join_lobby")
    lockLevel = endpoints:WaitForChild("request_lock_level")
    requestLeaderboard = endpoints:WaitForChild("request_infinite_leaderboard")
end)
if not (endpoints and spawnUnitRemote and upgradeUnitRemote and voteRemote and matchmakingRemote) then bildirimGoster("KRİTİK HATA: Oyunun fonksiyonları bulunamadı.") return end

-- Özel Alan Savunucusu Döngüsü
coroutine.wrap(function()
    while true do
        task.wait(0.2)
        if not scriptAktif or (inSequenceArea and sequenceSystemActive) or sequenceEditorOpen or not mainAndSpecialActive then continue end

        local character = localPlayer.Character
        if not (character and character.PrimaryPart) then
            if specialAreaStatusLabel then specialAreaStatusLabel.Text = "Özel Alan: PASİF"; specialAreaStatusLabel.TextColor3 = Color3.fromRGB(220, 80, 80) end
            continue
        end

        local playerPos = character.PrimaryPart.Position
        inAnySpecialArea = false
        for _, alan in ipairs(OZEL_ALANLAR) do
            if not alan.last_check then alan.last_check = 0 end
            if (playerPos - alan.trigger_pos).Magnitude <= alan.trigger_radius then
                inAnySpecialArea = true
                if os.clock() - alan.last_check >= alan.cooldown then
                    alan.last_check = os.clock()
                    bildirimGoster(alan.name .. " için alana girildi. Birimler yerleştiriliyor...")
                    for _, placement in ipairs(alan.placements) do
                        pcall(function() spawnUnitRemote:InvokeServer(placement.id, placement.data, 0) end)
                        task.wait(0.1)
                    end
                end
            end
        end
        
        if specialAreaStatusLabel then
            specialAreaStatusLabel.Text = inAnySpecialArea and "Özel Alan: AKTİF" or "Özel Alan: PASİF"
            specialAreaStatusLabel.TextColor3 = inAnySpecialArea and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(220, 80, 80)
        end
    end
end)()

-- Sıralama Yöneticisi ve Çalıştırıcısı Döngüsü
coroutine.wrap(function()
    local active_sequence_thread = nil
    
    local function checkAndManageSequence()
        if not scriptAktif then
            if inSequenceArea then
                inSequenceArea = false
                if sequenceStatusLabel then sequenceStatusLabel.Text = "Görev Sıralaması: PASİF"; sequenceStatusLabel.TextColor3 = Color3.fromRGB(220, 80, 80) end
                if active_sequence_thread then task.cancel(active_sequence_thread); active_sequence_thread = nil end
            end
            return
        end
        
        local character = localPlayer.Character
        if not (character and character.PrimaryPart) then return end
        
        local playerPos = character.PrimaryPart.Position
        local wasInArea = inSequenceArea
        local foundArea = false
        local currentSequence = nil
        
        for _, seq in ipairs(all_sequences_cache) do
            if seq and seq.trigger_area and seq.trigger_area.pos then
                local triggerPos = vector.create(seq.trigger_area.pos.X, seq.trigger_area.pos.Y, seq.trigger_area.pos.Z)
                if (playerPos - triggerPos).Magnitude <= seq.trigger_area.radius then
                    foundArea = true; currentSequence = seq; break
                end
            end
        end
        inSequenceArea = foundArea

        if sequenceStatusLabel then
            if not sequenceSystemActive then
                sequenceStatusLabel.Text = "Sıralama Sistemi: DEAKTİF"
                sequenceStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            else
                sequenceStatusLabel.Text = inSequenceArea and "Görev Sıralaması: AKTİF" or "Görev Sıralaması: PASİF"
                sequenceStatusLabel.TextColor3 = inSequenceArea and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(220, 80, 80)
            end
        end
        
        if inSequenceArea and not wasInArea and sequenceSystemActive then
            bildirimGoster("'".. (currentSequence.name or "İsimsiz") .."' görev alanına girildi! Ana otomasyon durduruldu.")
            if active_sequence_thread then task.cancel(active_sequence_thread) end
            
            active_sequence_thread = task.spawn(function()
                while inSequenceArea and scriptAktif and sequenceSystemActive do
                    local sequenceStartTime = os.clock()
                    local tasksDone = {}
                    local totalDuration = 0
                    for _, task in ipairs(currentSequence.tasks) do totalDuration = math.max(totalDuration, task.end_time) end

                    while inSequenceArea and scriptAktif and sequenceSystemActive and (os.clock() - sequenceStartTime <= totalDuration) do
                        local elapsedTime = os.clock() - sequenceStartTime
                        
                        if sequenceNameLabel then
                            sequenceNameLabel.Text = "Sıralama: " .. (currentSequence.name or "-")
                            sequenceProgressLabel.Text = string.format("İlerleme: %.0fs / %.0fs", elapsedTime, totalDuration)
                            
                            local activeTaskText = "Mevcut Görev: Bekleniyor..."
                            for _, action in ipairs(currentSequence.tasks) do
                                if elapsedTime >= action.start_time and elapsedTime <= action.end_time then
                                    local taskProgress = elapsedTime - action.start_time
                                    local taskDuration = action.end_time - action.start_time
                                    activeTaskText = string.format("Mevcut Görev: %s %s (%.0fs/%.0fs)", action.type, action.id or "", taskProgress, taskDuration)
                                    break
                                end
                            end
                            currentTaskLabel.Text = activeTaskText
                        end

                        for i, action in ipairs(currentSequence.tasks) do
                            if elapsedTime >= action.start_time and elapsedTime <= action.end_time then
                                if not tasksDone[i] then tasksDone[i] = {last_run = 0} end
                                if os.clock() - tasksDone[i].last_run >= action.interval then
                                    tasksDone[i].last_run = os.clock()
                                    if action.type == "Place" then
                                        local dir = action.direction or { X = 0, Y = -1, Z = 0 }
                                        pcall(function() 
                                            spawnUnitRemote:InvokeServer(action.id, {
                                                Origin=vector.create(action.origin.X, action.origin.Y, action.origin.Z), 
                                                Direction=vector.create(dir.X, dir.Y, dir.Z)
                                            }, 0) 
                                        end)
                                    elseif action.type == "Upgrade" then
                                        local unitsFolder = Workspace:FindFirstChild("_UNITS")
                                        if unitsFolder then
                                            for _, unit in ipairs(unitsFolder:GetChildren()) do
                                                if unit.Name:find(action.id, 1, true) then
                                                    pcall(function() upgradeUnitRemote:InvokeServer(unit.Name) end)
                                                    task.wait(0.1)
                                                end
                                            end
                                        end
                                    elseif action.type == "Code" then
                                        local f, err = loadstring(action.code)
                                        if f then pcall(f) else warn("Özel kod hatası: ", err) end
                                    elseif action.type == "Replay" then
                                        local args = {"replay"}; pcall(function() voteRemote:InvokeServer(unpack(args)) end)
                                    elseif action.type == "Leave" then
                                        local args = {}; pcall(function() teleportToLobby:InvokeServer(unpack(args)) end)
                                    elseif action.type == "Next Story" then
                                        local args = {"next_story"}; pcall(function() voteRemote:InvokeServer(unpack(args)) end)
                                    elseif action.type == "Next Event" then
                                        local args = {"_GATE", {GateUuid = 1}}; pcall(function() matchmakingRemote:InvokeServer(unpack(args)) end)
                                    end
                                end
                            end
                        end
                        task.wait(0.5)
                    end
                    
                    if not (currentSequence.repeat_sequence and inSequenceArea and scriptAktif and sequenceSystemActive) then
                        break -- Tekrarlama kapalıysa veya alandan çıkıldıysa döngüden çık
                    end
                    bildirimGoster("'"..currentSequence.name.."' sıralaması tekrarlanıyor...")
                    task.wait(1)
                end
            end)
        elseif not inSequenceArea and wasInArea then
            bildirimGoster("Görev alanından çıkıldı. Ana otomasyon devam ediyor.")
            if active_sequence_thread then task.cancel(active_sequence_thread); active_sequence_thread = nil end
            if sequenceNameLabel then sequenceNameLabel.Text, sequenceProgressLabel.Text, currentTaskLabel.Text = "Sıralama: -", "İlerleme: -", "Mevcut Görev: -" end
        end
    end

    task.wait(2); loadAllSequences(); task.wait(1)
    local character = localPlayer.Character or localPlayer.CharacterAdded:Wait(); character:WaitForChild("HumanoidRootPart", 15); task.wait(1)
    checkAndManageSequence()
    game:GetService("RunService").Heartbeat:Connect(checkAndManageSequence)
end)()

-- Lobi Otomasyonu Döngüsü
coroutine.wrap(function()
    local lobbyCenter = vector.create(983.04, 360.86, 539.39)
    local lobbyRadius = 200

    local function isInLobby()
        local char = localPlayer.Character; if not (char and char.PrimaryPart) then return false end
        return (char.PrimaryPart.Position - lobbyCenter).Magnitude <= lobbyRadius
    end

    while true do
        task.wait(1)
        if not scriptAktif or not lobbyAutomationActive then continue end
        
        local wasInLobby = lobbyEntryTime > 0
        local isCurrentlyInLobby = isInLobby()
        if lobbyStatusLabel then lobbyStatusLabel.Text = "Konum: " .. (isCurrentlyInLobby and "Lobide" or "Lobi Dışında") end
        
        if isCurrentlyInLobby and not wasInLobby then
            bildirimGoster("Lobiye girildi, otomasyon zamanlayıcısı başlatıldı.")
            lobbyEntryTime = os.clock()
            challengeAttempts = {}
        elseif not isCurrentlyInLobby and wasInLobby then
            bildirimGoster("Lobiden çıkıldı.")
            lobbyEntryTime = 0
        end

        if not isCurrentlyInLobby then
            local currentTime = os.date("*t")
            if (currentTime.min == 0 or currentTime.min == 30) and (currentTime.min ~= lastChallengeSlot.minute or currentTime.hour ~= lastChallengeSlot.hour) then
                lastChallengeSlot = {hour = currentTime.hour, minute = currentTime.min}
                bildirimGoster("Lobi dışında, zaman tetiklendi. Lobiye dönülüyor...")
                local args = {}
                pcall(function() teleportToLobby:InvokeServer(unpack(args)) end)
            end
        else -- Lobide ise
            local timeInLobby = os.clock() - lobbyEntryTime
            
            if timeInLobby >= 30 and not challengeAttempts[30] then
                challengeAttempts[30] = true
                bildirimGoster("Lobide 30 saniye geçti, Challenge deneniyor...")
                local args = {"ChallengePod6"}; pcall(function() joinLobby:InvokeServer(unpack(args)) end)
            end

            if timeInLobby >= 60 and not challengeAttempts[60] then
                challengeAttempts[60] = true
                bildirimGoster("Lobide 60 saniye geçti, Challenge tekrar deneniyor...")
                local args = {"ChallengePod6"}; pcall(function() joinLobby:InvokeServer(unpack(args)) end)
            end

            if timeInLobby >= 90 and not challengeAttempts[90] then
                challengeAttempts[90] = true
                task.wait(1) -- Check again if still in lobby
                if isInLobby() then
                    bildirimGoster("Challenge başarısız, sonraki moda geçiliyor: " .. lobbyNextMode)
                    if lobbyNextMode == "Event" then
                        local args = {"_GATE", {GateUuid = 1}}; pcall(function() matchmakingRemote:InvokeServer(unpack(args)) end)
                    elseif lobbyNextMode == "Infinite" then
                        local args1 = {"P6"}; pcall(function() joinLobby:InvokeServer(unpack(args1)) end); task.wait(3)
                        local args2 = {"namek_infinite"}; pcall(function() requestLeaderboard:InvokeServer(unpack(args2)) end); task.wait(3)
                        local args3 = {"P6", "namek_infinite", false, "Hard"}; pcall(function() lockLevel:InvokeServer(unpack(args3)) end)
                    elseif lobbyNextMode == "Alternative" then
                        local f, err = loadstring(lobbyAlternativeCode); if f then pcall(f) else warn("Alternatif kod hatası: ", err) end
                    end
                end
            end
        end
    end
end)()

-- Periyodik Oylama Döngüsü
coroutine.wrap(function()
    local lastVoteTime = 0
    while true do
        task.wait(1)
        if scriptAktif and not (inSequenceArea and sequenceSystemActive) and not sequenceEditorOpen then
            if os.clock() - lastVoteTime > OYLAMA_ARALIGI then
                lastVoteTime = os.clock()
                pcall(function() voteRemote:InvokeServer(sonucSecimi) end)
            end
        end
    end
end)()

-- Ana Yerleştirme Döngüsü
coroutine.wrap(function()
    while true do
        if not scriptAktif or (inSequenceArea and sequenceSystemActive) or sequenceEditorOpen or not mainAndSpecialActive then
            task.wait(0.2)
            continue
        end
        
        local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
        if not humanoidRootPart then
            task.wait(1)
            continue
        end
        
        local baslangicKonumu = humanoidRootPart.Position
        local settings = loadMainSettings()
        
        local currentRadius, currentAngle, placementAttemptCounter = 2, 0, 0
        local angleIncrement = 0.4
        local radiusIncrement = settings.spiral_step

        for i = 1, #YERLESTIRILECEK_BIRIM_SIRALAMASI do
            local unitIdToPlace = YERLESTIRILECEK_BIRIM_SIRALAMASI[i]
            local placedSuccessfully = false
            
            while not placedSuccessfully and currentRadius <= settings.radius do
                if not scriptAktif or (inSequenceArea and sequenceSystemActive) or sequenceEditorOpen or not mainAndSpecialActive then
                    task.wait(0.2)
                    continue
                end
                
                local pPos = baslangicKonumu + vector.create(currentRadius * math.cos(currentAngle), 0, currentRadius * math.sin(currentAngle))
                local dirVec = (pPos - (baslangicKonumu + vector.create(0, 20, 0))).Unit
                local success, result = pcall(function() return spawnUnitRemote:InvokeServer(unitIdToPlace, {Origin=pPos, Direction=dirVec}, 0) end)
                
                if success and result then
                    lastPlacedUnitId = tostring(result):sub(1,15)
                    if lastUnitIdLabel then lastUnitIdLabel.Text = "Son ID: " .. lastPlacedUnitId end
                    placedSuccessfully = true
                    task.wait(YERLESTIRME_BEKLEME_SURESI)
                else
                    task.wait(0.25)
                end

                currentAngle = currentAngle + angleIncrement
                if currentAngle > (math.pi * 2) then
                    currentAngle = 0
                    currentRadius = currentRadius + radiusIncrement
                end
                
                placementAttemptCounter = placementAttemptCounter + 1
                if placementAttemptCounter >= 5 then
                    placementAttemptCounter = 0
                    local unitsFolder = Workspace:FindFirstChild("_UNITS")
                    if unitsFolder then
                        for _, unitInstance in ipairs(unitsFolder:GetChildren()) do
                             pcall(function() upgradeUnitRemote:InvokeServer(unitInstance.Name) end)
                             task.wait(YUKSELTME_BEKLEME_SURESI)
                        end
                    end
                end
            end
        end
        pcall(function() voteRemote:InvokeServer(sonucSecimi) end)
        task.wait(5)
    end
end)()

