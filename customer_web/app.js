// =============================================
// MudhuLoka RestoBar — Customer Ordering App
// Supabase-powered self-ordering via QR scan
// =============================================

// ---- CONFIGURATION ----
// These MUST match your Supabase project credentials
var SUPABASE_URL = 'https://rmigsrrkhtffkdhizlvt.supabase.co';
var SUPABASE_ANON_KEY = 'sb_publishable_CktHbqQrGzIye6vC-_Gbdw_-yeywwHC';

// ---- STATE ----
var sb = null;
var tableId = null;
var tableName = '';
var categories = [];
var menuItems = [];
var cart = {};
var activeCategory = null;
var isViewOnly = false;
var isNamedMode = false;
var customerName = '';

// ---- INIT ----
document.addEventListener('DOMContentLoaded', function() {
  initApp();
});

async function initApp() {
  try {
    console.log('initApp starting...');

    var params = new URLSearchParams(window.location.search);
    tableId = params.get('table');
    isViewOnly = true;
    isNamedMode = false;
    
    console.log('Forced View Only Mode');

    console.log('Table ID:', tableId);
    console.log('View Only Mode:', isViewOnly);
    console.log('Named Mode:', isNamedMode);

    var createClient = window.supabase.createClient;
    sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    console.log('Supabase client created');

    if (isNamedMode) {
      customerName = localStorage.getItem('customer_name') || '';
      if (!customerName) {
        customerName = prompt('Please enter your name to view the menu and order:');
        if (customerName) {
          customerName = customerName.trim();
          localStorage.setItem('customer_name', customerName);
        }
      }
      
      if (!customerName) {
        showError('Name is required for this ordering mode. Please reload and enter your name.');
        return;
      }
      
      tableName = 'Named Order';
      document.getElementById('table-name').textContent = 'Order for ' + customerName;
    } else if (isViewOnly) {
      tableName = 'Menu';
      document.getElementById('table-name').textContent = 'Viewing Menu';
    } else {
      var tableResult = await sb.from('tables').select('*').eq('id', tableId).single();
      console.log('Table result:', tableResult);

      if (tableResult.error || !tableResult.data) {
        showError('Invalid table. Please scan a valid QR code.');
        return;
      }

      tableName = tableResult.data.name;
      document.getElementById('table-name').textContent = tableName;
    }

    var catResult = await sb.from('categories').select('*').order('name');
    if (catResult.error) throw catResult.error;
    categories = catResult.data || [];
    
    // Sort categories according to custom menu priority (Starters -> Tandoori -> Main Course -> Biryani etc.)
    categories.sort(function(a, b) {
      var pA = getCategoryPriority(a.name);
      var pB = getCategoryPriority(b.name);
      if (pA !== pB) return pA - pB;
      return a.name.localeCompare(b.name);
    });
    
    console.log('Categories loaded and sorted by custom menu priority:', categories.length);

    var itemResult = await sb.from('menu_items').select('*').order('name');
    if (itemResult.error) throw itemResult.error;
    menuItems = itemResult.data || [];
    
    // Sort items inside each category in ascending order of price
    menuItems.sort(function(a, b) {
      if (a.price !== b.price) {
        return a.price - b.price;
      }
      return a.name.localeCompare(b.name);
    });
    
    console.log('Menu items loaded and sorted by ascending price:', menuItems.length);

    renderCategoryTabs();
    renderMenu();

    document.getElementById('search-input').addEventListener('input', handleSearch);

    hideLoading();
    console.log('App initialized successfully!');

  } catch (err) {
    console.error('Init error:', err);
    showError('Failed to load menu. Please try again.');
  }
}

// ---- LOADING / ERROR ----
function hideLoading() {
  var loading = document.getElementById('loading-screen');
  loading.classList.add('fade-out');
  setTimeout(function() { loading.classList.add('hidden'); }, 500);
  document.getElementById('app').classList.remove('hidden');
}

function showError(message) {
  document.getElementById('loading-screen').classList.add('hidden');
  document.getElementById('error-message').textContent = message;
  document.getElementById('error-screen').classList.remove('hidden');
}

// ---- CATEGORY TABS ----
function renderCategoryTabs() {
  var container = document.getElementById('category-tabs');
  container.innerHTML = '';

  var allTab = document.createElement('button');
  allTab.className = 'category-tab active';
  allTab.textContent = 'All';
  allTab.onclick = function() { setActiveCategory(null, allTab); };
  container.appendChild(allTab);

  categories.forEach(function(cat) {
    var tab = document.createElement('button');
    tab.className = 'category-tab';
    tab.textContent = cat.name;
    tab.onclick = function() { setActiveCategory(cat.id, tab); };
    container.appendChild(tab);
  });
}

function setActiveCategory(catId, tabElement) {
  activeCategory = catId;
  document.querySelectorAll('.category-tab').forEach(function(t) { t.classList.remove('active'); });
  tabElement.classList.add('active');
  tabElement.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
  renderMenu();
}

// ---- SEARCH ----
function handleSearch(e) {
  var query = e.target.value.trim();
  document.getElementById('search-clear').classList.toggle('hidden', !query);
  renderMenu();
}

function clearSearch() {
  var input = document.getElementById('search-input');
  input.value = '';
  document.getElementById('search-clear').classList.add('hidden');
  renderMenu();
  input.focus();
}

// ---- RENDER MENU ----
function renderMenu() {
  var container = document.getElementById('menu-container');
  var searchQuery = document.getElementById('search-input').value.toLowerCase().trim();
  var filteredItems = menuItems;

  if (activeCategory) {
    filteredItems = filteredItems.filter(function(item) { return item.category_id === activeCategory; });
  }

  if (searchQuery) {
    filteredItems = filteredItems.filter(function(item) {
      return item.name.toLowerCase().includes(searchQuery);
    });
  }

  if (filteredItems.length === 0) {
    container.innerHTML =
      '<div class="empty-state">' +
        '<div class="empty-state-icon">🔍</div>' +
        '<div class="empty-state-text">No items found</div>' +
      '</div>';
    return;
  }

  if (!activeCategory && !searchQuery) {
    var html = '';
    categories.forEach(function(cat) {
      var catItems = filteredItems.filter(function(i) { return i.category_id === cat.id; });
      if (catItems.length === 0) return;
      html += '<div class="menu-category-title">' + escapeHtml(cat.name) + '</div>';
      catItems.forEach(function(item, idx) {
        html += renderMenuItem(item, idx);
      });
    });
    container.innerHTML = html;
  } else {
    container.innerHTML = filteredItems.map(function(item, idx) { return renderMenuItem(item, idx); }).join('');
  }
}

function getEmojiForItem(name) {
  var n = name.toLowerCase();
  if (n.includes('biriyani') || n.includes('rice')) return '\u{1F35A}';
  if (n.includes('chicken') || n.includes('mutton') || n.includes('kabab')) return '\u{1F357}';
  if (n.includes('drink') || n.includes('juice') || n.includes('shake') || n.includes('soda')) return '\u{1F379}';
  if (n.includes('veg') || n.includes('salad') || n.includes('paneer')) return '\u{1F957}';
  if (n.includes('dessert') || n.includes('ice') || n.includes('sweet')) return '\u{1F368}';
  if (n.includes('fish') || n.includes('prawn')) return '\u{1F41F}';
  if (n.includes('bread') || n.includes('roti') || n.includes('naan')) return '\u{1FAD3}';
  return '\u{1F37D}\u{FE0F}';
}

function renderMenuItem(item, index) {
  var qty = cart[item.id] || 0;
  var inCartClass = qty > 0 ? 'in-cart' : '';
  var controls = '';
  
  if (isViewOnly) {
    controls = '';
  } else {
    if (qty > 0) {
      controls =
        '<button class="btn-qty btn-remove" onclick="removeFromCart(\'' + item.id + '\')">−</button>' +
        '<span class="item-qty">' + qty + '</span>';
    }
    controls += '<button class="btn-qty btn-add" onclick="addToCart(\'' + item.id + '\')">+</button>';
  }

  var cleanName = item.name.replace(/[^\x00-\x7F]/g, "").trim();

  return '<div class="menu-item ' + inCartClass + '" id="item-' + item.id + '" style="animation-delay: ' + (index * 0.03) + 's">' +
    '<div class="menu-item-info">' +
      '<div class="menu-item-name">' + escapeHtml(cleanName) + '</div>' +
      (item.description ? '<div class="menu-item-description">' + escapeHtml(item.description) + '</div>' : '') +
    '</div>' +
    '<div class="menu-item-price" style="font-size: 1.2rem; font-weight: 800; color: var(--accent);">₹' + Number(item.price).toFixed(2) + '</div>' +
  '</div>';
}

// ---- CART ----
function addToCart(itemId) {
  cart[itemId] = (cart[itemId] || 0) + 1;
  var el = document.getElementById('item-' + itemId);
  if (el) {
    el.classList.add('item-added-flash');
    setTimeout(function() { el.classList.remove('item-added-flash'); }, 400);
  }
  renderMenu();
  updateCartBar();
}

function removeFromCart(itemId) {
  if (cart[itemId] && cart[itemId] > 1) {
    cart[itemId]--;
  } else {
    delete cart[itemId];
  }
  renderMenu();
  updateCartBar();
}

function updateCartBar() {
  if (isViewOnly) return;
  var bar = document.getElementById('cart-bar');
  var totalItems = Object.values(cart).reduce(function(s, q) { return s + q; }, 0);
  var totalPrice = getCartTotal();

  if (totalItems === 0) {
    bar.classList.add('hidden');
    return;
  }

  bar.classList.remove('hidden');
  document.getElementById('cart-count').textContent = totalItems;
  document.getElementById('cart-total').textContent = '₹' + totalPrice.toFixed(2);
}

function getCartTotal() {
  var total = 0;
  Object.entries(cart).forEach(function(entry) {
    var item = menuItems.find(function(m) { return m.id === entry[0]; });
    if (item) total += item.price * entry[1];
  });
  return total;
}

// ---- CART MODAL ----
function showCartModal() {
  var modal = document.getElementById('cart-modal');
  var cartItemsContainer = document.getElementById('cart-items');
  var html = '';

  Object.entries(cart).forEach(function(entry) {
    var itemId = entry[0];
    var qty = entry[1];
    var item = menuItems.find(function(m) { return m.id === itemId; });
    if (!item) return;

    html +=
      '<div class="cart-item">' +
        '<div class="cart-item-info">' +
          '<div class="cart-item-name">' + escapeHtml(item.name) + '</div>' +
          '<div class="cart-item-price">₹' + Number(item.price).toFixed(2) + ' × ' + qty + '</div>' +
        '</div>' +
        '<div class="cart-item-controls">' +
          '<button class="btn-qty btn-remove" onclick="removeFromCartModal(\'' + itemId + '\')">−</button>' +
          '<span class="item-qty">' + qty + '</span>' +
          '<button class="btn-qty btn-add" onclick="addToCartModal(\'' + itemId + '\')">+</button>' +
        '</div>' +
        '<div class="cart-item-total">₹' + (item.price * qty).toFixed(2) + '</div>' +
      '</div>';
  });

  if (!html) {
    html =
      '<div class="empty-state">' +
        '<div class="empty-state-icon">🛒</div>' +
        '<div class="empty-state-text">Your cart is empty</div>' +
      '</div>';
  }

  cartItemsContainer.innerHTML = html;
  var total = getCartTotal();
  document.getElementById('modal-subtotal').textContent = '₹' + total.toFixed(2);
  document.getElementById('modal-total').textContent = '₹' + total.toFixed(2);
  modal.classList.remove('hidden');
  document.body.style.overflow = 'hidden';
}

function hideCartModal() {
  document.getElementById('cart-modal').classList.add('hidden');
  document.body.style.overflow = '';
}

function handleModalOverlayClick(event) {
  if (event.target === event.currentTarget) {
    hideCartModal();
  }
}

function addToCartModal(itemId) {
  addToCart(itemId);
  showCartModal();
}

function removeFromCartModal(itemId) {
  removeFromCart(itemId);
  var totalItems = Object.values(cart).reduce(function(s, q) { return s + q; }, 0);
  if (totalItems === 0) {
    hideCartModal();
  } else {
    showCartModal();
  }
}

var isSubmittingOrder = false;

// ---- PLACE ORDER ----
async function placeOrder() {
  if (isSubmittingOrder) return;
  
  var totalItems = Object.values(cart).reduce(function(s, q) { return s + q; }, 0);
  if (totalItems === 0) return;

  isSubmittingOrder = true;
  var btn = document.getElementById('place-order-btn');
  var btnText = btn.querySelector('.btn-text');
  var btnLoader = btn.querySelector('.btn-loader');

  btn.disabled = true;
  btnText.textContent = 'Placing Order...';
  btnLoader.classList.remove('hidden');

  try {
    var total = getCartTotal();
    
    // In named mode, use the stored name. Otherwise check the input field or default to null.
    var orderCustomerName = isNamedMode ? customerName : (document.getElementById('customer-name').value.trim() || null);

    // Check for existing pending order
    var query = sb.from('orders').select('id, total_amount').eq('status', 'pending');
    
    if (isNamedMode) {
      query = query.eq('customer_info', orderCustomerName);
    } else if (tableId) {
      query = query.eq('table_id', tableId);
    } else {
      throw new Error('Cannot place order without table or name');
    }

    var existingResult = await query.maybeSingle();
    if (existingResult.error) throw existingResult.error;

    var existingOrder = existingResult.data;
    var orderId;

    if (existingOrder) {
      // Append to existing order
      orderId = existingOrder.id;
      var currentTotal = Number(existingOrder.total_amount);

      var updateResult = await sb.from('orders').update({ total_amount: currentTotal + total }).eq('id', orderId);
      if (updateResult.error) throw updateResult.error;

    } else {
      // Create new order
      var orderData = {
        total_amount: total,
        status: 'pending',
        order_source: 'customer',
        customer_info: orderCustomerName,
      };
      
      if (tableId) {
        orderData.table_id = tableId;
      }

      var orderResult = await sb
        .from('orders')
        .insert(orderData)
        .select()
        .single();

      if (orderResult.error) throw orderResult.error;
      orderId = orderResult.data.id;
    }

    // We need to fetch existing items first to merge quantities, avoiding duplicate rows
    var existingItems = [];
    if (existingOrder) {
      var itemsResult = await sb.from('order_items').select('*').eq('order_id', orderId);
      if (!itemsResult.error && itemsResult.data) {
        existingItems = itemsResult.data;
      }
    }

    var mergedItems = [...existingItems];

    Object.entries(cart).forEach(function(entry) {
      var menuItemId = entry[0];
      var quantity = entry[1];
      var itemData = menuItems.find(function(m) { return m.id === menuItemId; });
      var price = itemData ? itemData.price : 0;

      var existingIndex = mergedItems.findIndex(function(i) { return i.menu_item_id === menuItemId; });
      if (existingIndex >= 0) {
        mergedItems[existingIndex].quantity = Number(mergedItems[existingIndex].quantity) + Number(quantity);
      } else {
        mergedItems.push({
          order_id: orderId,
          menu_item_id: menuItemId,
          quantity: quantity,
          price: price
        });
      }
    });

    if (existingOrder) {
      // Delete old items so we can re-insert the merged list cleanly
      await sb.from('order_items').delete().eq('order_id', orderId);
    }

    // Clean up IDs before inserting so Supabase generates new ones
    var itemsToInsert = mergedItems.map(function(item) {
      return {
        order_id: item.order_id,
        menu_item_id: item.menu_item_id,
        quantity: item.quantity,
        printed_quantity: item.printed_quantity || 0,
        price: item.price
      };
    });

    var insertResult = await sb.from('order_items').insert(itemsToInsert);
    if (insertResult.error) throw insertResult.error;

    // Update table status if needed
    if (tableId) {
      await sb.from('tables').update({ status: 'occupied' }).eq('id', tableId);
    }

    hideCartModal();
    showSuccess();

  } catch (err) {
    console.error('Order error:', err);
    alert('Failed to place order. Please try again or call the waiter.');
    btn.disabled = false;
    btnText.textContent = 'Place Order';
    btnLoader.classList.add('hidden');
  } finally {
    isSubmittingOrder = false;
  }
}

// ---- SUCCESS ----
function showSuccess() {
  document.getElementById('success-screen').classList.remove('hidden');
  document.body.style.overflow = 'hidden';
}

function resetForNewOrder() {
  cart = {};
  isSubmittingOrder = false;
  updateCartBar();
  renderMenu();
  document.getElementById('success-screen').classList.add('hidden');
  document.getElementById('customer-name').value = '';
  document.body.style.overflow = '';

  var btn = document.getElementById('place-order-btn');
  btn.disabled = false;
  btn.querySelector('.btn-text').textContent = 'Place Order';
  btn.querySelector('.btn-loader').classList.add('hidden');
}

// ---- HELPERS ----
function getCategoryPriority(name) {
  var n = name.toLowerCase();
  if (n.includes('soup')) return 10;
  if (n.includes('starter')) return 20;
  if (n.includes('tandoori')) return 30;
  if (n.includes('chinese')) return 40;
  if (n.includes('main course')) return 50;
  if (n.includes('biryani') || n.includes('biriyani')) return 60;
  if (n.includes('rice')) return 70;
  if (n.includes('noodle')) return 80;
  if (n.includes('bread') || n.includes('roti') || n.includes('naan')) return 90;
  if (n.includes('salad')) return 100;
  if (n.includes('mocktail')) return 110;
  if (n.includes('cocktail')) return 120;
  if (n.includes('drink')) return 130;
  return 200; // fallback for others
}

function escapeHtml(text) {
  var div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
