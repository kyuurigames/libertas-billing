function dateStringToTimestamp(dateString) {
    try {
        const date = new Date(dateString);
        return date.getTime();
    } catch (error) {
        console.error('Date parsing error:', error);
        return 0;
    }
}

function isOverdue(dueDateString, status) {
    if (status !== 'unpaid') return false;
    
    const dueTimestamp = dateStringToTimestamp(dueDateString);
    const currentTimestamp = Date.now();
    
    return currentTimestamp > dueTimestamp;
}let playerData = null;
let currentBills = [];
let currentNearbyPlayers = [];
let currentPlayers = [];
let confirmCallback = null;

document.addEventListener('DOMContentLoaded', function() {
    setupTabNavigation();
    setupEventListeners();
    document.getElementById('app').style.display = 'none';
    window.resourceName = 'qb-billing';
});

function setupTabNavigation() {
    const tabBtns = document.querySelectorAll('.tab-btn');
    const tabPanes = document.querySelectorAll('.tab-pane');
    
    tabBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            const tabName = this.dataset.tab;

            tabBtns.forEach(b => {
                b.classList.remove('border-blue-500', 'text-blue-600', 'bg-blue-50');
                b.classList.add('border-transparent', 'text-gray-600');
            });
            tabPanes.forEach(p => p.style.display = 'none');
            
            this.classList.remove('border-transparent', 'text-gray-600');
            this.classList.add('border-blue-500', 'text-blue-600', 'bg-blue-50');
            document.getElementById(tabName + '-tab').style.display = 'block';

            if (tabName === 'create') {
                loadNearbyPlayers();
            } else if (tabName === 'police') {
                loadNearbyPlayersForPolice();
            }
        });
    });

    const firstTab = document.querySelector('.tab-btn');
    if (firstTab) {
        firstTab.click();
    }
}

function setupEventListeners() {
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeBilling();
        }
    });
    
    document.getElementById('app').addEventListener('click', function(e) {
        if (e.target === this) {
            closeBilling();
        }
    });
    
    document.getElementById('confirmDialog').addEventListener('click', function(e) {
        if (e.target === this) {
            closeConfirmDialog();
        }
    });
}

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'openUI':
            playerData = data.playerData;
            if (data.resourceName) {
                window.resourceName = data.resourceName;
            }
            
            document.getElementById('userName').textContent = playerData.name;
            
            const policeTab = document.querySelector('[data-tab="police"]');
            if (playerData.isPolice || playerData.isAdmin) {
                policeTab.style.display = 'flex';
            } else {
                policeTab.style.display = 'none';
            }
            
            document.getElementById('app').style.display = 'flex';
            break;
            
        case 'closeUI':
            document.getElementById('app').style.display = 'none';
            break;
            
        case 'loadBills':
            currentBills = data.bills;
            renderBills();
            break;
            
        case 'showPlayerBills':
            showSelectedPlayerBills(data.playerName, data.bills);
            break;
    }
});

function renderBills() {
    const billsList = document.getElementById('billsList');
    const filter = document.getElementById('statusFilter').value;
    
    let filteredBills = currentBills;
    
    if (filter !== 'all') {
        filteredBills = currentBills.filter(bill => {
            switch(filter) {
                case 'unpaid':
                    return bill.status === 'unpaid';
                case 'paid':
                    return bill.status === 'paid';
                case 'sent':
                    return bill.is_sender;
                case 'received':
                    return !bill.is_sender;
                default:
                    return true;
            }
        });
    }
    
    if (filteredBills.length === 0) {
        billsList.innerHTML = `
            <div class="text-center py-12">
                <i class="fas fa-receipt text-4xl text-gray-300 mb-4"></i>
                <h3 class="text-lg font-medium text-gray-500 mb-2">請求書がありません</h3>
                <p class="text-sm text-gray-400">該当する請求書が見つかりませんでした。</p>
            </div>
        `;
        return;
    }
    
    billsList.innerHTML = filteredBills.map(bill => {
        const isOverdueStatus = isOverdue(bill.due_date, bill.status);
        const isPaid = bill.status === 'paid';
        const canPay = !bill.is_sender && bill.status === 'unpaid';
        
        let statusBadge = '';
        let borderClass = 'border-gray-200';
        
        if (isOverdueStatus) {
            statusBadge = '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">期限切れ</span>';
            borderClass = 'border-red-200 bg-red-50';
        } else if (isPaid) {
            statusBadge = '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">支払い済み</span>';
            borderClass = 'border-green-200';
        } else {
            statusBadge = '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">未払い</span>';
            borderClass = 'border-yellow-200';
        }
        
        return `
            <div class="bill-item bg-white border ${borderClass} rounded-lg p-4 shadow-sm">
                <div class="flex items-start justify-between mb-3">
                    <div>
                        <h3 class="font-semibold text-gray-900">${bill.is_sender ? bill.receiver_name : bill.sender_name}</h3>
                        <p class="text-2xl font-bold text-blue-600">¥${formatNumber(bill.amount)}</p>
                    </div>
                    ${statusBadge}
                </div>
                
                <div class="grid grid-cols-2 gap-4 mb-3 text-sm">
                    <div>
                        <span class="text-gray-500">${bill.is_sender ? '宛先' : '送信者'}</span>
                        <p class="font-medium text-gray-900">${bill.is_sender ? bill.receiver_name : bill.sender_name}</p>
                    </div>
                    <div>
                        <span class="text-gray-500">作成日</span>
                        <p class="font-medium text-gray-900">${formatDate(bill.created_at)}</p>
                    </div>
                    <div>
                        <span class="text-gray-500">期限</span>
                        <p class="font-medium text-gray-900">${formatDate(bill.due_date)}</p>
                    </div>
                    ${bill.paid_at ? `
                    <div>
                        <span class="text-gray-500">支払日</span>
                        <p class="font-medium text-gray-900">${formatDate(bill.paid_at)}</p>
                    </div>
                    ` : '<div></div>'}
                </div>
                
                <div class="bg-gray-50 rounded-lg p-3 mb-3">
                    <span class="text-xs text-gray-500 uppercase tracking-wide">理由</span>
                    <p class="text-sm text-gray-700 mt-1">${bill.reason}</p>
                </div>
                
                ${canPay ? `
                <div class="flex justify-end">
                    <button onclick="payBill(${bill.id}, ${bill.amount})" class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors duration-200">
                        <i class="fas fa-credit-card mr-2"></i>
                        支払う (¥${formatNumber(bill.amount)})
                    </button>
                </div>
                ` : ''}
            </div>
        `;
    }).join('');
}

function loadNearbyPlayers() {
    fetch(`https://${GetParentResourceName()}/getNearbyPlayers`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(players => {
        console.log('Received players:', players);
        currentPlayers = players || [];
        renderPlayerSelect();
    }).catch(error => {
        console.error('Error loading nearby players:', error);
        currentPlayers = [];
        renderPlayerSelect();
    });
}

function loadNearbyPlayersForPolice() {
    const nearbyPlayersList = document.getElementById('nearbyPlayersList');
    nearbyPlayersList.innerHTML = `
        <div class="flex justify-center items-center py-8">
            <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-red-600"></div>
            <span class="ml-3 text-gray-600">近くのプレイヤーを検索中...</span>
        </div>
    `;
    
    fetch(`https://${GetParentResourceName()}/getNearbyPlayers`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(players => {
        console.log('Received nearby players for police:', players);
        currentNearbyPlayers = players || [];
        renderNearbyPlayers();
    }).catch(error => {
        console.error('Error loading nearby players for police:', error);
        currentNearbyPlayers = [];
        renderNearbyPlayers();
    });
}

function renderNearbyPlayers() {
    const nearbyPlayersList = document.getElementById('nearbyPlayersList');
    
    if (currentNearbyPlayers.length === 0) {
        nearbyPlayersList.innerHTML = `
            <div class="text-center py-8">
                <i class="fas fa-users text-3xl text-gray-300 mb-3"></i>
                <h3 class="text-md font-medium text-gray-500 mb-2">近くにプレイヤーがいません</h3>
                <p class="text-sm text-gray-400">5メートル以内にプレイヤーがいません。</p>
            </div>
        `;
        return;
    }
    
    nearbyPlayersList.innerHTML = currentNearbyPlayers.map(player => {
        return `
            <div class="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow duration-200 cursor-pointer" onclick="checkPlayerBills(${player.id})">
                <div class="flex items-center justify-between">
                    <div>
                        <h3 class="font-semibold text-gray-900">${player.name}</h3>
                        <p class="text-sm text-gray-500">ID: ${player.id}</p>
                    </div>
                    <div class="text-right">
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            ${player.distance}m
                        </span>
                        <div class="mt-1">
                            <button class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                                <i class="fas fa-search mr-1"></i>
                                請求書確認
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

function checkPlayerBills(playerId) {
    fetch(`https://${GetParentResourceName()}/checkPlayerBills`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            targetId: playerId
        })
    });
}

function showSelectedPlayerBills(playerName, bills) {
    const selectedPlayerBills = document.getElementById('selectedPlayerBills');
    const playerBillsList = document.getElementById('playerBillsList');
    
    selectedPlayerBills.style.display = 'block';
    
    if (bills.length === 0) {
        playerBillsList.innerHTML = `
            <div class="text-center py-6 bg-green-50 border border-green-200 rounded-lg">
                <i class="fas fa-check-circle text-2xl text-green-500 mb-2"></i>
                <h3 class="text-md font-medium text-green-800 mb-1">${playerName}</h3>
                <p class="text-sm text-green-600">未払い請求書はありません</p>
            </div>
        `;
        return;
    }
    
    const unpaidBills = bills.filter(bill => bill.status === 'unpaid');
    const totalAmount = unpaidBills.reduce((sum, bill) => sum + bill.amount, 0);
    
    playerBillsList.innerHTML = `
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
            <div class="flex items-center justify-between">
                <div>
                    <h3 class="font-semibold text-red-900">${playerName}</h3>
                    <p class="text-sm text-red-700">未払い請求書: ${unpaidBills.length}件</p>
                </div>
                <div class="text-right">
                    <p class="text-lg font-bold text-red-600">¥${formatNumber(totalAmount)}</p>
                    <p class="text-xs text-red-500">総未払い額</p>
                </div>
            </div>
        </div>
        
        <div class="space-y-2 max-h-32 overflow-y-auto scrollbar-thin">
            ${bills.map(bill => {
                const isOverdueStatus = isOverdue(bill.due_date, bill.status);
                const isPaid = bill.status === 'paid';
                
                let statusClass = 'bg-yellow-100 text-yellow-800';
                let statusText = '未払い';
                
                if (isOverdueStatus) {
                    statusClass = 'bg-red-100 text-red-800';
                    statusText = '期限切れ';
                } else if (isPaid) {
                    statusClass = 'bg-green-100 text-green-800';
                    statusText = '支払い済み';
                }
                
                return `
                    <div class="bg-white border border-gray-200 rounded p-3">
                        <div class="flex items-center justify-between mb-2">
                            <span class="font-medium text-gray-900">¥${formatNumber(bill.amount)}</span>
                            <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${statusClass}">
                                ${statusText}
                            </span>
                        </div>
                        <p class="text-sm text-gray-600 mb-1">${bill.reason}</p>
                        <div class="flex justify-between text-xs text-gray-500">
                            <span>送信者: ${bill.sender_name}</span>
                            <span>期限: ${formatDate(bill.due_date)}</span>
                        </div>
                    </div>
                `;
            }).join('')}
        </div>
    `;
}

function refreshNearbyPlayers() {
    loadNearbyPlayersForPolice();
}

function loadPlayers() {
    loadNearbyPlayers();
}

function renderPlayerSelect() {
    const select = document.getElementById('targetPlayer');
    select.innerHTML = '<option value="">近くのプレイヤーを選択してください</option>';
    
    if (currentPlayers.length === 0) {
        const option = document.createElement('option');
        option.value = '';
        option.textContent = '近くにプレイヤーがいません (5m以内)';
        option.disabled = true;
        select.appendChild(option);
        return;
    }
    
    currentPlayers.forEach(player => {
        const option = document.createElement('option');
        option.value = player.id;
        option.textContent = `${player.name} (${player.distance}m)`;
        select.appendChild(option);
    });
}

function createBill() {
    const targetId = document.getElementById('targetPlayer').value;
    const amount = document.getElementById('billAmount').value;
    const reason = document.getElementById('billReason').value;
    
    if (!targetId) {
        showNotification('近くのプレイヤーを選択してください', 'error');
        return;
    }
    
    if (!amount || amount < 1) {
        showNotification('有効な金額を入力してください', 'error');
        return;
    }
    
    if (!reason.trim()) {
        showNotification('理由を入力してください', 'error');
        return;
    }
    
    fetch(`https://${GetParentResourceName()}/createBill`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            targetId: parseInt(targetId),
            amount: parseInt(amount),
            reason: reason.trim()
        })
    }).then(resp => resp.json()).then(resp => {
        if (resp !== 'error') {
            document.getElementById('targetPlayer').value = '';
            document.getElementById('billAmount').value = '';
            document.getElementById('billReason').value = '';
            document.querySelector('[data-tab="bills"]').click();
        }
    });
}

function payBill(billId, amount) {
    showConfirmDialog(
        '支払い確認',
        `¥${formatNumber(amount)}を支払いますか？`,
        () => {
            fetch(`https://${GetParentResourceName()}/payBill`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({
                    billId: billId
                })
            });
        }
    );
}

function refreshBills() {
    const refreshBtn = document.querySelector('.tab-pane:not([style*="display: none"]) button[onclick="refreshBills()"]');
    if (refreshBtn) {
        const originalContent = refreshBtn.innerHTML;
        refreshBtn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>更新中...';
        refreshBtn.disabled = true;
        
        fetch(`https://${GetParentResourceName()}/refreshBills`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({})
        }).then(() => {
            setTimeout(() => {
                refreshBtn.innerHTML = originalContent;
                refreshBtn.disabled = false;
            }, 1000);
        });
    }
}

function loadUnpaidBills() {
    loadNearbyPlayersForPolice();
}

function refreshUnpaidBills() {
    refreshNearbyPlayers();
}

function filterBills() {
    renderBills();
}

function showConfirmDialog(title, message, callback) {
    document.getElementById('confirmTitle').textContent = title;
    document.getElementById('confirmMessage').textContent = message;
    document.getElementById('confirmDialog').style.display = 'flex';
    confirmCallback = callback;
}

function closeConfirmDialog() {
    document.getElementById('confirmDialog').style.display = 'none';
    confirmCallback = null;
}

function confirmAction() {
    if (confirmCallback) {
        confirmCallback();
    }
    closeConfirmDialog();
}

function closeBilling() {
    fetch(`https://${GetParentResourceName()}/closeBilling`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    });
}

function showNotification(message, type = 'info') {
    console.log(`[${type.toUpperCase()}] ${message}`);
}

function formatNumber(num) {
    return new Intl.NumberFormat('ja-JP').format(num);
}

function formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diffTime = Math.abs(now - date);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    const options = {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    };
    
    const formattedDate = date.toLocaleDateString('ja-JP', options);

    if (diffDays === 0) {
        return `今日 ${date.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;
    } else if (diffDays === 1) {
        return `昨日 ${date.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })}`;
    } else if (diffDays < 7) {
        return `${diffDays}日前`;
    } else {
        return formattedDate;
    }
}

function GetParentResourceName() {
    return window.resourceName || 'qb-billing';
}