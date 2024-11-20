-- services
local runService = game:GetService("RunService");
local players = game:GetService("Players");
local workspace = game:GetService("Workspace");

-- variables
local localPlayer = players.LocalPlayer;
local camera = workspace.CurrentCamera;
local viewportSize = camera.ViewportSize;
local container = Instance.new("Folder",
	gethui and gethui() or game:GetService("CoreGui"));

-- locals
local floor = math.floor;
local round = math.round;
local sin = math.sin;
local cos = math.cos;
local clear = table.clear;
local unpack = table.unpack;
local find = table.find;
local create = table.create;
local fromMatrix = CFrame.fromMatrix;

-- methods
local wtvp = camera.WorldToViewportPoint;
local isA = workspace.IsA;
local getPivot = workspace.GetPivot;
local findFirstChild = workspace.FindFirstChild;
local findFirstChildOfClass = workspace.FindFirstChildOfClass;
local getChildren = workspace.GetChildren;
local toOrientation = CFrame.identity.ToOrientation;
local pointToObjectSpace = CFrame.identity.PointToObjectSpace;
local lerpColor = Color3.new().Lerp;
local min2 = Vector2.zero.Min;
local max2 = Vector2.zero.Max;
local lerp2 = Vector2.zero.Lerp;
local min3 = Vector3.zero.Min;
local max3 = Vector3.zero.Max;

-- constants
local HEALTH_BAR_OFFSET = Vector2.new(5, 0);
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0);
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1);
local NAME_OFFSET = Vector2.new(0, 2);
local DISTANCE_OFFSET = Vector2.new(0, 2);
local VERTICES = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
	Vector3.new(1, -1, 1)
};

-- functions
local function isBodyPart(Name)
	return Name == "Head" or Name:find("Torso") or Name:find("Leg") or Name:find("Arm");
end

local function getBoundingBox(parts)
	local min, max;
	for i = 1, #parts do
		local part = parts[i];
		local cframe, size = part.CFrame, part.Size;

		min = min3(min or cframe.Position, (cframe - size*0.5).Position);
		max = max3(max or cframe.Position, (cframe + size*0.5).Position);
	end

	local center = (min + max)*0.5;
	local front = Vector3.new(center.X, center.Y, max.Z);
	return CFrame.new(center, front), max - min;
end

local function worldToScreen(world)
	local screen, inBounds = wtvp(camera, world);
	return Vector2.new(screen.X, screen.Y), inBounds, screen.Z;
end

local function calculateCorners(cframe, size)
	local corners = create(#VERTICES);
	for i = 1, #VERTICES do
		corners[i] = worldToScreen((cframe + size*0.5*VERTICES[i]).Position);
	end

	local min = min2(viewportSize, unpack(corners));
	local max = max2(Vector2.zero, unpack(corners));
	return {
		corners = corners,
		topLeft = Vector2.new(floor(min.X), floor(min.Y)),
		topRight = Vector2.new(floor(max.X), floor(min.Y)),
		bottomLeft = Vector2.new(floor(min.X), floor(max.Y)),
		bottomRight = Vector2.new(floor(max.X), floor(max.Y))
	};
end

local function rotateVector(vector, radians)
	-- https://stackoverflow.com/questions/28112315/how-do-i-rotate-a-vector
	local x, y = vector.X, vector.Y;
	local c, s = cos(radians), sin(radians);
	return Vector2.new(x*c - y*s, x*s + y*c);
end

local function parseColor(self, color, isOutline)
	if color == "Team Color" or (self.interface.sharedSettings.TeamColor and not isOutline) then
		return self.interface.getTeamColor(self.Player) or Color3.new(1,1,1);
	end
	return color;
end

-- esp object
local EspObject = {};
EspObject.__index = EspObject;

function EspObject.new(Player, interface)
	local Self = setmetatable({}, EspObject);
	Self.Player = assert(Player, "Missing argument #1 (Player expected)");
	Self.interface = assert(interface, "Missing argument #2 (table expected)");
	Self:Construct();
	return Self;
end

function EspObject:_create(class, properties)
	local drawing = Drawing.new(class);
	for property, value in next, properties do
		pcall(function() drawing[property] = value; end);
	end
	bin[#bin + 1] = drawing;
	return drawing
end

function EspObject:Construct()
	self.charCache = {}
	self.childCount = 0
	bin = {}
	drawings = {
		Box3D = {
			{
				EspObject:_create("Line", { Thickness = 1, Visible = false }),
				EspObject:_create("Line", { Thickness = 1, Visible = false }),
				EspObject:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				EspObject:_create("Line", { Thickness = 1, Visible = false }),
				EspObject:_create("Line", { Thickness = 1, Visible = false }),
				EspObject:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				EspObject:_create("Line", { Thickness = 1, Visible = false }),
				EspObject:_create("Line", { Thickness = 1, Visible = false }),
				EspObject:_create("Line", { Thickness = 1, Visible = false })
			},
			{
				EspObject:_create("Line", { Thickness = 1, Visible = false }),
				EspObject:_create("Line", { Thickness = 1, Visible = false }),
				EspObject:_create("Line", { Thickness = 1, Visible = false })
			}
		},
		visible = {
			TracerOutline = self:_create("Line", { Thickness = 3, Visible = false }),
			Tracer = self:_create("Line", { Thickness = 1, Visible = false }),
			BoxFill = self:_create("Square", { Filled = true, Visible = false }),
			BoxOutline = self:_create("Square", { Thickness = 3, Visible = false }),
			Box = self:_create("Square", { Thickness = 1, Visible = false }),
			HealthBarOutline = self:_create("Line", { Thickness = 3, Visible = false }),
			HealthBar = self:_create("Line", { Thickness = 1, Visible = false }),
			healthText = self:_create("Text", { Center = true, Visible = false }),
			Name = self:_create("Text", { Text = self.Player.DisplayName, Center = true, Visible = false }),
			Distance = self:_create("Text", { Center = true, Visible = false }),
			Weapon = self:_create("Text", { Center = true, Visible = false }),
		},
		hidden = {
			arrowOutline = self:_create("Triangle", { Thickness = 3, Visible = false }),
			arrow = self:_create("Triangle", { Filled = true, Visible = false })
		}
	};
	print(drawings.visible.BoxFill)
	print("sigma man")
	self.renderConnection = runService.Heartbeat:Connect(function(deltaTime)
		self:Update(deltaTime);
		self:Render(deltaTime);
	end);
end

function EspObject:Destruct()
	self.renderConnection:Disconnect();

	for i = 1, #bin do
		bin[i]:Remove();
	end

	clear(self);
end

function EspObject:Update()
	if true then
		return
	end
	local interface = self.interface;

	self.Options = interface.teamSettings[interface.isFriendly(self.Player) and "friendly" or "enemy"];
	self.Character = interface.getCharacter(self.Player);
	self.Health, self.MaxHealth = interface.getHealth(self.Player);
	self.Weapon = interface.getWeapon(self.Player);
	self.Enabled = interface.sharedSettings.Enabled and self.Character and not
	(#interface.whitelist > 0 and not find(interface.whitelist, self.Player.UserId));

	local head = self.Enabled and findFirstChild(self.Character, "Head");
	if not head then
		self.charCache = {};
		self.onScreen = false;
		return;
	end

	local _, onScreen, depth = worldToScreen(head.Position);
	self.onScreen = onScreen;
	self.Distance = depth; 

	if interface.sharedSettings.limitDistance and depth > interface.sharedSettings.maxDistance then
		self.onScreen = false;
	end

	if self.onScreen then
		local cache = self.charCache;
		local children = getChildren(self.Character);
		if not cache[1] or self.childCount ~= #children then
			clear(cache);

			for i = 1, #children do
				local part = children[i];
				if isA(part, "BasePart") and isBodyPart(part.Name) then
					cache[#cache + 1] = part;
				end
			end

			self.childCount = #children;
		end

		self.corners = calculateCorners(getBoundingBox(cache));
	elseif self.Options.offScreenArrow then
		local cframe = camera.CFrame;
		local flat = fromMatrix(cframe.Position, cframe.RightVector, Vector3.yAxis);
		local objectSpace = pointToObjectSpace(flat, head.Position);
		self.direction = Vector2.new(objectSpace.X, objectSpace.Z).Unit;
	end
end

function EspObject:Render()
	local onScreen = self.onScreen or false;
	local Enabled = self.Enabled or false;
	local visible = drawings.visible;
	local hidden = drawings.hidden;
	local Box3D = drawings.Box3D;
	local interface = self.interface;
	local Options = self.Options;
	local corners = self.corners;

	visible.Box.Visible = Enabled and onScreen and interface.sharedSettings.Box
	visible.BoxOutline.Visible = visible.Box.Visible and interface.sharedSettings.BoxOutline
	if visible.Box.Visible then
		local Box = visible.Box
		Box.Position = corners.topLeft
		Box.Size = corners.bottomRight - corners.topLeft
		Box.Color = parseColor(self, interface.sharedSettings.BoxColor[1])
		Box.Transparency = interface.sharedSettings.BoxColor[2]

		local BoxOutline = visible.BoxOutline;
		BoxOutline.Position = Box.Position;
		BoxOutline.Size = Box.Size;
		BoxOutline.Color = parseColor(self, interface.sharedSettings.BoxOutlineColor[1], true)
		BoxOutline.Transparency = interface.sharedSettings.BoxOutlineColor[2]
	end
	visible.BoxFill.Visible = Enabled and onScreen and interface.sharedSettings.BoxFill
	print(visible.Boxfill)
	if visible.Boxfill.Visible then
		local BoxFill = visible.BoxFill;
		BoxFill.Position = corners.topLeft;
		BoxFill.Size = corners.bottomRight - corners.topLeft;
		BoxFill.Color = parseColor(self, Options.BoxFillColor[1]);
		BoxFill.Transparency = interface.sharedSettings.BoxFillColor[2];
	end

	visible.HealthBar.Visible = Enabled and onScreen and  interface.sharedSettings.HealthBar;
	visible.HealthBarOutline.Visible = visible.HealthBar.Visible and interface.sharedSettings.BoxOutline;
	if visible.HealthBar.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET;
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET;

		local HealthBar = visible.HealthBar;
		HealthBar.To = barTo;
		HealthBar.From = lerp2(barTo, barFrom, self.health/self.maxHealth);
		HealthBar.Color = lerpColor(interface.sharedSettings.DyingColor, interface.sharedSettings.HealthyColor, self.health/self.maxHealth);

		local HealthBarOutline = visible.HealthBarOutline;
		HealthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET;
		HealthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET;
		HealthBarOutline.Color = parseColor(self, interface.sharedSettings.BoxOutlineColor[1], true);
		HealthBarOutline.Transparency = interface.sharedSettings.BoxOutlineColor[2];
	end

	visible.healthText.Visible = Enabled and onScreen and Options.healthText;
	if visible.healthText.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET;
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET;

		local HealthText = visible.healthText;
		HealthText.Text = round(self.health) .. "hp";
		HealthText.Size = interface.sharedSettings.TextSize;
		HealthText.Font = interface.sharedSettings.TextFont;
		HealthText.Color = parseColor(self, interface.sharedSettings.BoxColor[1]);
		HealthText.Transparency = interface.sharedSettings.BoxColor[2];
		HealthText.Outline =  interface.sharedSettings.BoxOutline;
		HealthText.OutlineColor = parseColor(self, interface.sharedSettings.BoxOutlineColor, true);
		HealthText.Position = lerp2(barTo, barFrom, self.health/self.maxHealth) - HealthText.TextBounds*0.5 - HEALTH_TEXT_OFFSET;
	end

	visible.Name.Visible = Enabled and onScreen and Options.Name;
	if visible.Name.Visible then
		local Name = visible.Name;
		Name.Size = interface.sharedSettings.TextSize;
		Name.Font = interface.sharedSettings.TextFont;
		Name.Color = parseColor(self, interface.sharedSettings.BoxColor);
		Name.Transparency = interface.sharedSettings.BoxColor[2];
		Name.Outline =  interface.sharedSettings.BoxOutline;
		Name.OutlineColor = parseColor(self,  interface.sharedSettings.BoxOutlineColor, true);
		Name.Position = (corners.topLeft + corners.topRight)*0.5 - Vector2.yAxis*Name.TextBounds.Y - NAME_OFFSET;
	end

	visible.Distance.Visible = Enabled and onScreen and self.Distance and Options.Distance;
	if visible.Distance.Visible then
		local Distance = visible.Distance;
		Distance.Text = round(self.Distance) .. " studs";
		Distance.Size = interface.sharedSettings.TextSize;
		Distance.Font = interface.sharedSettings.TextFont;
		Distance.Color = parseColor(self, interface.sharedSettings.BoxColor[1]);
		Distance.Transparency = interface.sharedSettings.BoxColor[2];
		Distance.Outline = interface.sharedSettings.BoxOutline;
		Distance.OutlineColor = parseColor(self, interface.sharedSettings.BoxOutlineColor, true);
		Distance.Position = (corners.bottomLeft + corners.bottomRight)*0.5 + DISTANCE_OFFSET;
	end

	visible.Weapon.Visible = Enabled and onScreen and Options.Weapon;
	if visible.Weapon.Visible then
		local Weapon = visible.Weapon;
		Weapon.Text = self.Weapon;
		Weapon.Size = interface.sharedSettings.TextSize;
		Weapon.Font = interface.sharedSettings.TextFont;
		Weapon.Color = parseColor(self, interface.sharedSettings.BoxColor[1]);
		Weapon.Transparency = interface.sharedSettings.BoxColor[2];
		Weapon.Outline = interface.sharedSettings.BoxOutline;
		Weapon.OutlineColor = parseColor(self, interface.sharedSettings.BoxOutlineColor, true);
		Weapon.Position =
			(corners.bottomLeft + corners.bottomRight)*0.5 +
			(visible.Distance.Visible and DISTANCE_OFFSET + Vector2.yAxis*visible.Distance.TextBounds.Y or Vector2.zero);
	end

	visible.Tracer.Visible = Enabled and onScreen and Options.Tracer;
	visible.TracerOutline.Visible = visible.Tracer.Visible and Options.TracerOutline;
	if visible.Tracer.Visible then
		local Tracer = visible.Tracer;
		Tracer.Color = parseColor(self, Options.TracerColor[1]);
		Tracer.Transparency = Options.TracerColor[2];
		Tracer.To = (corners.bottomLeft + corners.bottomRight)*0.5;
		Tracer.From =
			Options.TracerOrigin == "Middle" and viewportSize*0.5 or
			Options.TracerOrigin == "Top" and viewportSize*Vector2.new(0.5, 0) or
			Options.TracerOrigin == "Bottom" and viewportSize*Vector2.new(0.5, 1);

		local TracerOutline = visible.TracerOutline;
		TracerOutline.Color = parseColor(self, interface.sharedSettings.TracerOutlineColor[1], true);
		TracerOutline.Transparency = interface.sharedSettings.TracerOutlineColor[2];
		TracerOutline.To = Tracer.To;
		TracerOutline.From = Tracer.From;
	end

	local Box3DEnabled = Enabled and onScreen and interface.sharedSettings.Box3D;
	for i = 1, #Box3D do
		local face = Box3D[i];
		for i2 = 1, #face do
			local line = face[i2];
			line.Visible = Box3DEnabled;
			line.Color = parseColor(self, interface.sharedSettings.Box3DColor[1]);
			line.Transparency = interface.sharedSettings.Box3DColor[2];
		end

		if Box3DEnabled then
			local line1 = face[1];
			line1.From = corners.corners[i];
			line1.To = corners.corners[i == 4 and 1 or i+1];

			local line2 = face[2];
			line2.From = corners.corners[i == 4 and 1 or i+1];
			line2.To = corners.corners[i == 4 and 5 or i+5];

			local line3 = face[3];
			line3.From = corners.corners[i == 4 and 5 or i+5];
			line3.To = corners.corners[i == 4 and 8 or i+4];
		end
	end
end

-- cham object
local ChamObject = {};
ChamObject.__index = ChamObject;

function ChamObject.new(Player, interface)
	local Self = setmetatable({}, ChamObject);
	Self.Player = assert(Player, "Missing argument #1 (Player expected)");
	Self.interface = assert(interface, "Missing argument #2 (table expected)");
	Self:Construct();
	return Self;
end

function ChamObject:Construct()
	self.HighLight = Instance.new("Highlight", container);
	self.updateConnection = runService.Heartbeat:Connect(function()
		self:Update();
	end);
end

function ChamObject:Destruct()
	self.updateConnection:Disconnect();
	self.HighLight:Destroy();

	clear(self);
end

function ChamObject:Update()
	local HighLight = self.HighLight;
	local interface = self.interface;
	local Character = interface.getCharacter(self.Player);
	local Options = interface.teamSettings[interface.isFriendly(self.Player) and "friendly" or "enemy"];
	local Enabled = interface.sharedSettings.Enabled and Character and not
	(#interface.whitelist > 0 and not find(interface.whitelist, self.Player.UserId));

	HighLight.Enabled = Enabled and interface.sharedSettings.ChamsEnabled;
	if HighLight.Enabled then
		HighLight.Adornee = Character;
		HighLight.FillColor = parseColor(self, interface.sharedSettings.ChamsFillColor[1]);
		HighLight.FillTransparency = interface.sharedSettings.ChamsFillColor[2];
		HighLight.OutlineColor = parseColor(self, interface.sharedSettings.ChamsOutlineColor[1], true);
		HighLight.OutlineTransparency = interface.sharedSettings.ChamsOutlineColor[2];
		HighLight.DepthMode = interface.sharedSettings.ChamsVisibilityType and "Occluded" or "AlwaysOnTop";
	end
end

-- instance class
local InstanceObject = {};
InstanceObject.__index = InstanceObject;

function InstanceObject.new(instance, Options)
	local Self = setmetatable({}, InstanceObject);
	Self.instance = assert(instance, "Missing argument #1 (Instance Expected)");
	Self.Options = assert(Options, "Missing argument #2 (table expected)");
	Self:Construct();
	return Self;
end

function InstanceObject:Construct()
	local Options = self.Options;
	Options.Enabled = Options.Enabled == nil and true or Options.Enabled;
	Options.Text = Options.Text or "{Name}";
	Options.TextColor = Options.TextColor or { Color3.new(1,1,1), 1 };
	Options.TextOutline = Options.TextOutline == nil and true or Options.TextOutline;
	Options.TextOutlineColor = Options.TextOutlineColor or Color3.new();
	Options.TextSize = Options.TextSize or 13;
	Options.TextFont = Options.TextFont or 2;
	Options.LimitDistance = Options.LimitDistance or false;
	Options.MaxDistance = Options.MaxDistance or 150;

	self.Text = Drawing.new("Text");
	self.Text.Center = true;

	self.renderConnection = runService.Heartbeat:Connect(function(deltaTime)
		self:Render(deltaTime);
	end);
end

function InstanceObject:Destruct()
	self.renderConnection:Disconnect();
	self.Text:Remove();
end

function InstanceObject:Render()
	local instance = self.instance;
	if not instance or not instance.Parent then
		return self:Destruct();
	end

	local Text = self.Text;
	local Options = self.Options;
	if not Options.Enabled then
		Text.Visible = false;
		return;
	end

	local world = getPivot(instance).Position;
	local position, visible, depth = worldToScreen(world);
	if Options.limitDistance and depth > Options.maxDistance then
		visible = false;
	end

	Text.Visible = visible;
	if Text.Visible then
		Text.Position = position;
		Text.Color = Options.textColor[1];
		Text.Transparency = Options.textColor[2];
		Text.Outline = Options.textOutline;
		Text.OutlineColor = Options.textOutlineColor;
		Text.Size = Options.textSize;
		Text.Font = Options.textFont;
		Text.Text = Options.Text
			:gsub("{Name}", instance.Name)
			:gsub("{Distance}", round(depth))
			:gsub("{position}", tostring(world));
	end
end

-- interface
local EspInterface = {
	_hasLoaded = false,
	_objectCache = {},
	whitelist = {},
	sharedSettings = {
		Enabled = false,
		IgnoreMyTeam = false,
		Box = true,
		BoxColor = { Color3.new(1,0,0), 1 },
		BoxOutline = false,
		BoxOutlineColor = { Color3.new(), 1 },
		BoxFill = false,
		BoxFillColor = { Color3.new(1,0,0), 0.5 },

		Name = false,
		Weapon = false,
		Distance = false,
		
		
		TextSize = 13,
		TextFont = 3,
		LimitDistance = false,
		MaxDistance = 150,
		TeamColor = false,
		
		HealthBar = false,
		HealthyColor = Color3.new(0,1,0),
		DyingColor = Color3.new(1,0,0),
		HealthText = false,
		Box3D = false,
		Box3DColor = { Color3.new(0,1,0), 1 },
		
		
		ChamsEnabled = false,
		ChamsVisibilityType = false,
		ChamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
		ChamsOutlineColor = { Color3.new(0,1,0), 0 },
		
		
		Tracer = false,
		TracerOrigin = "Bottom",
		TracerColor = { Color3.new(0,1,0), 1 },
		TracerOutline = true,
		TracerOutlineColor = { Color3.new(), 1 },
		
		
	},
	teamSettings = {
		enemy = {

			

		},
		friendly = {


		}
	}
};

function EspInterface.AddInstance(instance, Options)
	local cache = EspInterface._objectCache;
	if cache[instance] then
		warn("Instance handler already exists.");
	else
		cache[instance] = { InstanceObject.new(instance, Options) };
	end
	return cache[instance][1];
end

function EspInterface.Load()
	assert(not EspInterface._hasLoaded, "Esp has already been loaded.");

	local function createObject(Player)
		EspInterface._objectCache[Player] = {
			EspObject.new(Player, EspInterface),
			ChamObject.new(Player, EspInterface)
		};
	end

	local function removeObject(Player)
		local object = EspInterface._objectCache[Player];
		if object then
			for i = 1, #object do
				object[i]:Destruct();
			end
			EspInterface._objectCache[Player] = nil;
		end
	end

	local plrs = players:GetPlayers();
	for i = 2, #plrs do
		createObject(plrs[i]);
	end

	EspInterface.playerAdded = players.PlayerAdded:Connect(createObject);
	EspInterface.playerRemoving = players.PlayerRemoving:Connect(removeObject);
	EspInterface._hasLoaded = true;
end

function EspInterface.Unload()
	assert(EspInterface._hasLoaded, "Esp has not been loaded yet.");

	for index, object in next, EspInterface._objectCache do
		for i = 1, #object do
			object[i]:Destruct();
		end
		EspInterface._objectCache[index] = nil;
	end

	EspInterface.playerAdded:Disconnect();
	EspInterface.playerRemoving:Disconnect();
	EspInterface._hasLoaded = false;
end

-- game specific functions
function EspInterface.getWeapon(Player)
	return "Unknown";
end

function EspInterface.isFriendly(Player)
	return Player.Team and Player.Team == localPlayer.Team;
end

function EspInterface.getTeamColor(Player)
	return Player.Team and Player.Team.TeamColor and Player.Team.TeamColor.Color;
end

function EspInterface.getCharacter(Player)
	return Player.Character;
end

function EspInterface.getHealth(Player)
	local Character = Player and EspInterface.getCharacter(Player);
	local humanoid = Character and findFirstChildOfClass(Character, "Humanoid");
	if humanoid then
		return humanoid.Health, humanoid.MaxHealth;
	end
	return 100, 100;
end

return EspInterface;
